#!/bin/sh
###############################################################################
#
# do_GMI_GeoMatch.sh    Morris/SAIC/GPM GV    October 2014
#
# DESCRIPTION:
# Query gpmgv database for dates/times of rainy PR or GR events and assemble
# command string to do the TMI-GR geometry matching for events with data.
# Completed geometry match files are cataloged in the 'gpmgv' database table
# 'geo_match_products'.
#
# 10/7/2014   Morris        Created from doGeoMatch4NewRainCases.sh and
#                           do_DPR_GeoMatch.sh.
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
INSTRUMENT_ID="GMI"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2AGPROF"
export ALGORITHM

# override coded defaults with user-specified values
while getopts s:i:v:p:a:d:w: option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        a) ALGORITHM=${OPTARG};;
#        w) SWATH=${OPTARG};;
    esac
done

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/do_${SAT_ID}${INSTRUMENT_ID}_GeoMatch.${PPS_VERSION}.${rundate}.log

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2tmi procedure, as
# listed in the do_GMI_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_GMI_geo_matchup4date.sh by examining the do_GMI_geo_matchup4date.yymmdd.log 
# file. Formats catalog entry for the geo_match_product table in the gpmgv
# database, and loads the entries to the database.

YYMMDD=$1
DBCATALOGFILE=$2
SQL_BIN2=${BIN_DIR}/catalog_geo_match_products.sql
echo "Cataloging new matchup files listed in $DBCATALOGFILE"
# this same file is used in catalog_geo_match_products.sh and is also defined
# this way in catalog_geo_match_products.sql, which both scripts execute under
# psql.  Any changes to the name or format must be coordinated in all 3 files.

loadfile=${TMP_DIR}/catalogGeoMatchProducts.unl
if [ -f $loadfile ]
  then
    rm -v $loadfile
fi

for ncfile in `cat $DBCATALOGFILE`
  do
    radar_id=`echo ${ncfile} | cut -f4 -d '.'`
    orbit=`echo ${ncfile} | cut -f6 -d '.'`
    PR_VERSION=`echo ${ncfile} | cut -f7 -d '.'`
   # GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|1.2|1|${INSTRUMENT_ID}|${SAT_ID}|NA"
    gzfile=`ls ${ncfile}\.gz`
    if [ $? = 0 ]
      then
        echo "Found $gzfile" | tee -a $LOG_FILE
        rowdata="${rowpre}${gzfile}${rowpost}"
        echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
      else
        echo "Didn't find gzip version of $ncfile" | tee -a $LOG_FILE
        ungzfile=`ls ${ncfile}`
        if [ $? = 0 ]
          then
            echo "Found $ungzfile" | tee -a $LOG_FILE
            rowdata="${rowpre}${ungzfile}${rowpost}"
            echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
        fi
    fi
done

if [ -s $loadfile ]
  then
   # load the rows to the database
    echo "\i $SQL_BIN2" | psql -a -d gpmgv >> $LOG_FILE 2>&1
    tail $LOG_FILE | grep INSERT
fi

return
}
################################################################################

# Begin main script
echo "Starting ${SAT_ID}/${INSTRUMENT_ID}-GR matchups on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# update the list of rainy overpasses in database table 'rainy100inside100'
 if [ -s $SQL_BIN ]
   then
     echo "\i $SQL_BIN" # | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
   else
     echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     exit 1
 fi

# query finds unique dates where either of the PR "100 rain certain 4-km
# gridpoints within 100km" or the GR "100 2-km non-zero 2A-53 rainrate gridpoints"
# criteria are met, as encapsulated in the database VIEW rainy100merged_vw.  The
# latter query is much more likely to be met for a set of overpassed GR sites.
# - Excludes orbits whose TMI-GR matchup has already been created/cataloged,
#   and those for which 2A-5x products have not been received yet.

# re-used file to hold list of dates to run
datelist=${TMP_DIR}/doTMIGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -240`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

datestart="2015-09-30"
dateEnd='2015-10-05'

echo "Running GRtoGMI matchups for dates since $datestart" | tee -a $LOG_FILE

# here's a much faster query pair with the "left outer join geo_match_product"
# connected to a simple temp table
DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "SELECT c.* into temp tempevents \
from eventsatsubrad_vw c JOIN orbit_subset_product o \
  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
 AND o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
   and c.subset NOT IN ('KOREA','KORA','DARW') and c.nearest_distance<=${MAX_DIST} \
   and c.overpass_time at time zone 'UTC' > '${datestart}' \
   and c.overpass_time at time zone 'UTC' < '${dateEnd}' \
JOIN rainy100inside100 r on (c.event_num=r.event_num) order by c.overpass_time; \
select DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
  from tempevents c LEFT OUTER JOIN geo_match_product g \
    on c.radar_id=g.radar_id and c.orbit=g.orbit and c.sat_id=g.sat_id \
   and g.pps_version='${PPS_VERSION}' and g.instrument_id='${INSTRUMENT_ID}' \
   and g.PARAMETER_SET=${PARAMETER_SET} WHERE pathname is null order by 1;"`

#echo "2014-09-07" > $datelist
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
    echo "yymmdd = $yymmdd"
   # files to hold the delimited output from the database queries comprising the
   # control files for the TMI-GR matchup file creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/TMI_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/TMI_files_sites4geoMatch_temp.txt
    outfileall=${TMP_DIR}/TMI_files_sites4geoMatch.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of GMI 2AGPROF files to process, put in file $filelist

# here's a much faster query pair with the "left outer join geo_match_product"
# connected to a simple temp table
    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, c.radar_id, \
       '${yymmdd}'::text as datestamp, c.subset, d.version, \
       '${INSTRUMENT_ID}'::text as instrument, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename as file2a \
into temp possible_2agprof \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        AND c.subset NOT IN ('KOREA','KORA','DARW') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
      where cast(nominal at time zone 'UTC' as date) = '${thisdate}' and d.version = '$PPS_VERSION'; \
     select  c.file2a, c.orbit, count(*), c.datestamp, c.subset, c.version \
       from possible_2agprof c left outer join geo_match_product b on (c.radar_id=b.radar_id \
        and c.orbit=b.orbit and c.version=b.pps_version and b.instrument_id = 'GMI' \
        and b.parameter_set=0 and b.sat_id='GPM') where b.pathname is null \
   group by 1,2,4,5,6 order by c.orbit;"`  | tee -a $LOG_FILE 2>&1

echo "Contents of ${TMP_DIR}/TMI_filelist4geoMatch_temp.txt:"
cat ${TMP_DIR}/TMI_filelist4geoMatch_temp.txt
echo "End listing."

   # - Get a list of ground radars where precip is occurring for each included orbit,
   #  and prepare this date's control file for IDL to do TMI-GR matchup file creation.
   #  We now use temp tables and sorting by time difference between overpass_time and
   #  radar nominal time (nearest minute) to handle where the same radar_id
   #  comes up more than once for an orbit.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f2 -d '|'`
        subset=`echo $row | cut -f5 -d '|'`
#        echo "${orbit}, $subset, ${INSTRUMENT_ID}, $PPS_VERSION, ${thisdate}"

	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
            extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
            b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, c.file1cuf, c.tdiff \
          into temp timediftmp
          from overpass_event a, fixed_instrument_location b, rainy100inside100 r, \
	    collate_satsubprod_1cuf c \
            left outer join geo_match_product e on \
              (c.radar_id=e.radar_id and c.orbit=e.orbit and \
               c.version=e.pps_version and e.instrument_id = '${INSTRUMENT_ID}' \
               and e.parameter_set=${PARAMETER_SET} and e.sat_id='${SAT_ID}') \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num \
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            AND c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
            and pathname is null and c.version = '$PPS_VERSION' \
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
#    exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper scripts, do_GMI_geo_matchup4date.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_GMI_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_GMI_geo_matchup4date.sh $yymmdd

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_GMI_geo_matchup4date.sh"\
        	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_GMI_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $yymmdd $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE, quitting!"\
	         | tee -a $LOG_FILE
#                exit 1
            fi
          ;;
          1 )
            echo ""
            echo "FAILURE status returned from do_GMI_geo_matchup4date.sh, quitting!"\
	     | tee -a $LOG_FILE
	    exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_GMI_geo_matchup4date.sh, do nothing!"\
	     | tee -a $LOG_FILE
          ;;
        esac

        echo "" | tee -a $LOG_FILE
        end=`date -u`
        echo "Matchup script for $yymmdd completed on $end" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "=================================================================="\
        | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
    fi

done < $datelist

echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "See log file: $LOG_FILE"
exit
