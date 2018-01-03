#!/bin/sh
###############################################################################
#
# doGeoMatch4SelectCases.sh    Morris/SAIC/GPM GV    September 2008
#
# Wrapper to do PR-GV NetCDF geometric matchups for 1C21/2A25/2B31/1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# Criteria are as defined in the query which created and populated the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the PR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-25 product.  See file 'rainCases100.sql'.
#
# NOTE:  When running dates that might have already had PR-GV matchup sets
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match', either for the date(s) to be
#        run, or for all dates.
#
# 9/18/2008   Morris         Created from doGrids4Select100in100Cases.sh
# 12/2/2008   Morris         - Added capability to automatically determine the
#                            starting date of new data to process by looking at
#                            what files are in /data/netcdf/geo_match dir.
#                            - Eliminated duplicate no-data-file rows for RGSN
#                            due to the multiple PR subset hits for RGSN.
# 1/6/2009    Morris         - Substitute /1CUF-cal for /1CUF in the GV file
#                            path to point to "cal" version of KWAJ radar data.
# 8/15/2011   Morris         - Modify previous change, using a different VIEW
#                            (collatedGVproducts_kwajcal1) that returns 1CUF-cal
# 9/22/11     Morris         - Brought 1st query in line with current database
#                            cataloging and PR versioning to allow V7 to be
#                            processed.
# 9/23/11                    - Modified to query collatedGVproducts_kwajcal2,
#                            which handles both the pre-2008 KWAJ which is
#                            cataloged under product type 1CUF only, and the
#                            post-2007 which is cataloged under 1CUF-cal only.
#                            Restored the 1/6/2009 change to point the pre-2008
#                            results to the corresponding file under 1CUF-cal.
#
###############################################################################


GV_BASE_DIR=/home/morris/swdev
export GV_BASE_DIR
DATA_DIR=/data/gpmgv
export DATA_DIR
TMP_DIR=${DATA_DIR}/tmp
export TMP_DIR
LOG_DIR=${DATA_DIR}/logs
export LOG_DIR
GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR

PR_VERSION=6        # controls which PR products we process
export PR_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET

# set id of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="PR"
export INSTRUMENT_ID


rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/doGrids4SelectCases.${rundate}.log
export rundate

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2pr procedure, as
# listed in the do_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_geo_matchup4date.sh by examining the do_geo_matchup4date.yymmdd.log file. 
# Formats catalog entry for the geo_match_product table in the gpmgv database,
# and loads the entries to the database.

YYMMDD=$1
MATCHUP_LOG=${LOG_DIR}/do_geo_matchup4date.${YYMMDD}.log
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
    radar_id=`echo ${ncfile} | cut -f2 -d '.'`
    orbit=`echo ${ncfile} | cut -f4 -d '.'`
   # PR_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
   # GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PR_VERSION}|${PARAMETER_SET}|2.1|1|${INSTRUMENT_ID}"
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
    echo "\i $SQL_BIN2" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
fi

return
}
################################################################################

# Begin main script

echo "Starting PR and GV netCDF grid generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the orbit number in the subquery to just run grids for new dates/orbits.
# (Is now done inside the script with the smarts below!) Morris, 12/2008
#cd $GEO_NC_DIR
#ncfilemaxorbit=`ls | cut -f4 -d '.' | sort -run | head -1`
#echo "" | tee -a $LOG_FILE
#echo "Last orbit in existing geo_match netCDF file set = $ncfilemaxorbit"\
# | tee -a $LOG_FILE
#echo "" | tee -a $LOG_FILE

datelist=${DATA_DIR}/tmp/doGeoMatchSelectedDates_temp.txt
DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "select distinct \
  date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
from collatedprproductswsub c left outer join geo_match_product b \
  on (c.radar_id=b.radar_id and c.orbit=b.orbit and c.version=b.pps_version \
      and b.instrument_id='${INSTRUMENT_ID}') \
  join rainy100inside100 a on (a.orbit=c.orbit AND a.radar_id=c.radar_id) \
where pathname is null and c.radar_id = 'KWAJ' and \
  c.version=$PR_VERSION and a.orbit between 57571 and 62026 order by 1;"`
#echo "\t \a \f '|' \o $datelist \
#  \\\select distinct date(date_trunc('day', overpass_time at time zone 'UTC')) from \
#  collatedprproductswsub where orbit in \
#  (select distinct orbit from rainy100inside100 where radar_id = 'KWAJ' and orbit > 74522) \
#  order by 1;" | psql gpmgv | tee -a $LOG_FILE 2>&1

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build an IDL control file for each date and run the grids.

for thisdate in `cat $datelist`
do
yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
# files to hold the delimited output from the database queries comprising the
# control files for the 1C21/2A25/2B31 grid creation in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# dates, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/PR_filelist4geoMatch_temp.txt
outfile=${DATA_DIR}/tmp/PR_files_sites4geoMatch_temp.txt
outfileall=${DATA_DIR}/tmp/PR_files_sites4geoMatch.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of PR 1C21/2A25/2B31 files to process, put in file $filelist
# -- 2B31 file presence is considered optional for now

# Added "and file1c21 is not null" to WHERE clause to eliminate duplicate rows
# for RGSN's mapping to two subsets. Morris, 12/2008

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select file1c21, \
       COALESCE(file2a23, 'no_2A23_file') as file2a23, file2a25, \
       COALESCE(file2b31, 'no_2B31_file') as file2b31,\
       c.orbit, count(*), '${yymmdd}', subset, version \
     from collatedPRproductswsub c left outer join geo_match_product b on \
       (c.radar_id=b.radar_id and c.orbit=b.orbit and c.version=b.pps_version \
        and b.instrument_id = '${INSTRUMENT_ID}') \
       join rainy100inside100 a on (a.orbit=c.orbit AND a.radar_id=c.radar_id) \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
       and file1c21 is not null and pathname is null and version = $PR_VERSION \
       and c.radar_id = 'KWAJ' \
     group by file1c21, file2a23, file2a25, file2b31, c.orbit, subset, version \
     order by c.orbit;"`  | tee -a $LOG_FILE 2>&1
#echo "\t \a \f '|' \o $filelist \
#     \\\ select file1c21, file2a25, \
#     COALESCE(file2b31, 'no_2B31_file') as file2b31, \
#     a.orbit, count(*), '${yymmdd}', subset \
#     from collatedPRproductswsub a, rainy100inside100 b \
#     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
#     and a.orbit=b.orbit and a.radar_id=b.radar_id and file1c21 is not null \
#     and a.radar_id = 'KWAJ'\
#     group by file1c21, file2a25, file2b31, a.orbit, subset \
#     order by a.orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

# - Get a list of ground radars where precip is occurring for each included orbit,
#  and prepare this date's control file for IDL to do PR and GV grid file creation.

# 09/2008    Morris         - How to limit last query to 1 row for each event due to
#                             ARMOR 1CUF volumes, where Walt provided more than
#                             one UF volume file for some overpass events, which causes
#                             collatedGVproducts to produce duplicate/multiple rows?
#                             For now will order by radar_id and have IDL handle where
#                             the same radar_id comes up more than once for a case.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f5 -d '|'`
        subset=`echo $row | cut -f8 -d '|'`
	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', d.overpass_time at time zone 'UTC'), \
            extract(EPOCH from date_trunc('second', d.overpass_time)), \
            b.latitude, b.longitude, \
            trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') \
          from overpass_event a, fixed_instrument_location b, \
	    collatedGVproducts_kwajcal2 c, rainy100inside100 d, collatedprproductswsub p \
            left outer join geo_match_product e on \
              (p.radar_id=e.radar_id and p.orbit=e.orbit and \
               p.version=e.pps_version and e.instrument_id = '${INSTRUMENT_ID}')
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
	    and a.radar_id = d.radar_id and a.radar_id = p.radar_id \
	    and a.orbit = c.orbit and a.orbit = d.orbit and a.orbit = p.orbit \
            and a.orbit = ${orbit} and c.subset = '${subset}' and c.subset=p.subset
            and cast(d.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and a.radar_id = 'KWAJ' \
            and pathname is null and version = $PR_VERSION order by 3;"` \
        | tee -a $LOG_FILE 2>&1
#	echo "\t \a \f '|' \o $outfile \\\ select a.event_num, a.orbit, \
#            a.radar_id, date_trunc('second', d.overpass_time at time zone 'UTC'), \
#            extract(EPOCH from date_trunc('second', d.overpass_time)), \
#            b.latitude, b.longitude, \
#            trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') \
#            from overpass_event a, fixed_instrument_location b, \
#	  collatedGVproducts_kwajcal1 c, rainy100inside100 d \
#          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
#	    and a.radar_id = d.radar_id and a.radar_id = 'KWAJ' \
#	    and a.orbit = c.orbit  and a.orbit = d.orbit \
#            and a.orbit = ${orbit} and c.subset = '${subset}'
#          order by 3;" \
#      | psql -q gpmgv | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
#        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | sed 's[/1CUF/[/1CUF-cal/[' | tee -a $outfileall  | tee -a $LOG_FILE
    done

#exit

if [ -s $outfileall ]
  then
    # Call the IDL wrapper scripts, do_geo_matchup.sh, to run
    # the IDL .bat files.  Let each of these deal with whether the yymmdd
    # has been done before.

    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling do_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
    ${BIN_DIR}/do_geo_matchup4date.sh $yymmdd

    if [ $? = 0 ]
      then
        echo ""
        echo "SUCCESS status returned from do_geo_matchup4date.sh"\
	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $yymmdd $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE !"\
	         | tee -a $LOG_FILE
                #exit 1
            fi
      else
        echo ""
        echo "FAILURE status returned from do_geo_matchup4date.sh, quitting!"\
	 | tee -a $LOG_FILE
#	exit 1
    fi

    echo "" | tee -a $LOG_FILE
    end=`date -u`
    echo "Gridding scripts for $yymmdd completed on $end"\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "=================================================================="\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

done

exit
