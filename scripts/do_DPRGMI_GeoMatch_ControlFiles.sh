#!/bin/sh
###############################################################################
#
# do_DPRGMI_GeoMatch_ControlFiles.sh    Morris/SAIC/GPM GV    July 2016
#
# DESCRIPTION:
# Query gpmgv database for dates/times of rainy DPR or GR events and assemble
# date-specific command files to do the DPRGMI-GR geometry matching for rain
# events with data.  The script will skip the matchups and just create the
# control files.
#
# 7/12/2016   Morris         Created from do_DPRGMI_GeoMatch.sh.  Made default
#                            option to skip matchup/cataloging steps.  Changed
#                            location of control files to CTL_DIR.
#
###############################################################################


GV_BASE_DIR=/home/morris/swdev
export GV_BASE_DIR
DATA_DIR=/data/gpmgv
export DATA_DIR
TMP_DIR=/data/tmp
export TMP_DIR
LOG_DIR=/data/logs
export LOG_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION=V03D        # controls which GMI products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2tmi parameters (polar2tmi.bat file) in use
export PARAMETER_SET
MAX_DIST=250  # max radar-to-subtrack distance for overlap

# set ids of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="DPRGMI"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2BDPRGMI"
export ALGORITHM
GEO_MATCH_VERSION=1.3
export GEO_MATCH_VERSION

SKIP_NEWRAIN=0   # if 1, skip call to psql with SQL_BIN
DO_RHI=0         # if 1, then matchup to RHI UF files

# override coded defaults with user-specified values
while getopts s:i:v:p:a:d:m:kr option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        a) ALGORITHM=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        k) SKIP_NEWRAIN=1;;
        r) DO_RHI=1;;
    esac
done

echo "SKIP_NEWRAIN: $SKIP_NEWRAIN"
echo "DO_RHI: $DO_RHI"

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/doDPRGMIGeoMatchControlFiles.${PPS_VERSION}.${rundate}.log

umask 0002

# Begin main script
echo "Creating COMB-GR matchup control files on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

CTL_DIR=${DATA_DIR}/netcdf/geo_match/$SAT_ID/$ALGORITHM/$PPS_VERSION/CONTROL_FILES
export CTL_DIR
mkdir -p $CTL_DIR | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ "$SKIP_NEWRAIN" = "0" ]
  then
    # update the list of rainy overpasses in database table 'rainy100inside100'
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
      else
        echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        exit 1
    fi
  else
    echo "" | tee -a $LOG_FILE
    echo "Skipping update of database table rainy100inside100" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi


# query finds unique dates where either of the PR "100 rain certain 4-km
# gridpoints within 100km" or the GR "100 2-km non-zero 2A-53 rainrate gridpoints"
# criteria are met, as encapsulated in the database VIEW rainy100merged_vw.  The
# latter query is much more likely to be met for a set of overpassed GR sites.
# - Excludes orbits whose COMB-GR matchup has already been created/cataloged,
#   and those for which 2A-5x products have not been received yet.

# re-used file to hold list of dates to run
datelist=${TMP_DIR}/doCOMBGeoMatchSelectedDates_CTLtemp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -140`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`
#echo $datestart
datestart='2014-12-02'
echo "Running GRtoGMI matchups for dates since $datestart" | tee -a $LOG_FILE
dateEnd='2015-10-01'

DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "SELECT DISTINCT date(date_trunc('day', \
c.overpass_time at time zone 'UTC')) from eventsatsubrad_vw c \
LEFT JOIN orbit_subset_product o ON c.orbit = o.orbit AND c.subset = o.subset \
   AND c.sat_id = o.sat_id AND o.product_type = '${ALGORITHM}' \
   and c.subset NOT IN ('KOREA','KORA','DARW') and c.nearest_distance<=${MAX_DIST} \
   and c.overpass_time at time zone 'UTC' >= '${datestart}' \
   and c.overpass_time at time zone 'UTC' < '${dateEnd}' \
LEFT OUTER JOIN geo_match_product g on (c.event_num=g.event_num and \
   o.version=g.pps_version and g.instrument_id='${INSTRUMENT_ID}') \
JOIN rainy100inside100 r on (c.event_num=r.event_num) \
WHERE g.pathname is null and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' order by 1;"`

echo " "
echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

#exit

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build an IDL control file for each date and run the grids.

while read thisdate
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
#    echo "yymmdd = $yymmdd"
   # files to hold the delimited output from the database queries comprising the
   # control files for the COMB-GR matchup file creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelistold=${TMP_DIR}/COMB_filelist4geoMatch_CTLtemp.old.txt
    filelist=${TMP_DIR}/COMB_filelist4geoMatch_CTLtemp.txt
    outfile=${TMP_DIR}/COMB_files_sites4geoMatch_CTLtemp.txt
    outfileall=${CTL_DIR}/COMB_files_sites4geoMatch.${yymmdd}.new.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of 2B-DPRGMI files to process, put in file $filelist

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, count(*), \
       '${yymmdd}', c.subset, d.version, '${INSTRUMENT_ID}', \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename\
       as file2a12\
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        and c.subset NOT IN ('KOREA','KORA','DARW') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
     left outer join geo_match_product b on \
       (c.event_num=b.event_num and d.version=b.pps_version \
        and b.instrument_id = '${INSTRUMENT_ID}' and b.parameter_set=${PARAMETER_SET} \
        and b.geo_match_version=${GEO_MATCH_VERSION}) \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
       and b.pathname is null and d.version = '$PPS_VERSION' \
     group by 1,3,4,5,6,7 \
     order by c.orbit"`  | tee -a $LOG_FILE 2>&1

 echo "DPRGMI product metadata for ${yymmdd}:"
 cat ${filelist}
 echo "End listing."

#exit

   # - Get a list of ground radars where precip is occurring for each included orbit,
   #  and prepare this date's control file for IDL to do COMB-GR matchup file creation.
   #  We now use temp tables and sorting by time difference between overpass_time and
   #  radar nominal time (nearest minute) to handle where the same radar_id
   #  comes up more than once for an orbit.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f1 -d '|'`
        subset=`echo $row | cut -f4 -d '|'`
#        echo "${orbit}, $subset, ${INSTRUMENT_ID}, $PPS_VERSION, ${thisdate}"

	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
            extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
            b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, c.file1cuf, c.tdiff \
          into temp timediftmp
          from overpass_event a, fixed_instrument_location b, rainy100inside100 r, \
	    collate_satsubprod_1cuf c \
            left outer join geo_match_product e on \
              ( c.event_num=e.event_num and c.version=e.pps_version \
                and e.instrument_id = '${INSTRUMENT_ID}' \
                and e.parameter_set=${PARAMETER_SET} \
                and e.geo_match_version=${GEO_MATCH_VERSION} ) \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num \
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            AND c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
            and pathname is null and c.version = '$PPS_VERSION' \
            AND C.FILE1CUF NOT LIKE '%rhi%' \
          order by 3,9;
          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
            from timediftmp group by 1 order by 1;
          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b
                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
        | tee -a $LOG_FILE 2>&1

       # copy the temp file outputs from psql to the daily control file
        echo $row >> $outfileall
        cat $outfile >> $outfileall
    done

    echo ""
    echo "Control file ${outfileall} contents:"  | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
    cat $outfileall  | tee -a $LOG_FILE

    #exit  # if uncommented, creates the control file for first date, and exits

done < $datelist

echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "See log file: $LOG_FILE"
exit
