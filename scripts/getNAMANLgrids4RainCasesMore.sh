#!/bin/sh
###############################################################################
#
# getNAMANLgrids4RainCases.sh    Morris/SAIC/GPM GV    Feb 2011
#
# DESCRIPTION:
# Query gpmgv database for dates/times of rainy PR overpasses and assemble
# command string to download NAM Analysis grid subsets for the nearest
# cycle date/time from the NCDC NOMADS archives.  Uses PERL scripts
# get_inv.pl and get_grib.pl provided by NCEP to subset the GRIB files to
# the variables/levels of interest and download the subsetted GRIB files,
# which are then compressed using gzip.  Downloaded files are cataloged in the
# 'gpmgv' database table 'modelgrids'.
#
###############################################################################


GV_BASE_DIR=/home/morris
DATA_DIR=/data/gpmgv
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
GRIB_DATA=${DATA_DIR}/GRIB/NAMANL
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getNAMANLgrids4RainCases.${rundate}.log

echo "Starting NAM Analysis grid acquisition on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/getNAMANLdata_dbtempfile
# list of cycle datetimes to retrieve, as URL/file specs
NAMTOGET=${TMP_DIR}/getNAMANLdata_URLtempfile
if [ -f $NAMTOGET ]
  then
    rm -v $NAMTOGET | tee -a $LOG_FILE 2>&1
fi

echo "\t \a \o $DBTEMPFILE \\\select a.orbit, min(overpass_time at time zone 'UTC') \
  from rainy100inside100 a, orbit_subset_product b where a.orbit=b.orbit \
  and \
  date_trunc('month', date(overpass_time at time zone 'UTC')) = '2010-04-01' \
  group by 1 order by 1;" | psql gpmgv | tee -a $LOG_FILE 2>&1

while read line
  do
    prdatetime=`echo $line`
    orbit=`echo $prdatetime | cut -f1 -d '|'`
    yyyymmdd=`echo $prdatetime | cut -f2 -d '|' | cut -f1 -d ' ' | sed "s/-//g"`
    yyyymm=`echo $yyyymmdd | cut -c1-6`
    hh=`echo $prdatetime | cut -f2 -d ' ' | cut -c1-2`
    echo "" | tee -a $LOG_FILE
    echo "=====================================================================" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo $prdatetime | tee -a $LOG_FILE
    echo hh: $hh | tee -a $LOG_FILE
    cycle1=`expr $hh + 3`
    cycle2=`expr $cycle1 / 6`
    cycle=`expr $cycle2 \* 6`
    if [ `expr $cycle = 24` = 1 ]
      then
        echo "" | tee -a $LOG_FILE
        echo "Mapping to 00Z cycle of the following day, and incrementing day." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        cycle=0
        newyyyymmdd=`offset_date $yyyymmdd 1`
        yyyymmdd=$newyyyymmdd
        yyyymm=`echo $yyyymmdd | cut -c1-6`
    fi
    if [ `expr $cycle \< 10` = 1 ]
      then
        cycle=0$cycle
    fi
    echo yyyymmdd: $yyyymmdd | tee -a $LOG_FILE
    echo yyyymm: $yyyymm | tee -a $LOG_FILE
    echo cycle: $cycle | tee -a $LOG_FILE
    namfile="namanl_218_${yyyymmdd}_${cycle}00_000"
    dbdate=`echo $yyyymmdd | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
    dbcycle=${cycle}:00:00+00
    echo "${orbit}|${dbdate}|${dbcycle}|${yyyymm}/${yyyymmdd}/${namfile}" \
     | tee -a $NAMTOGET | tee -a $LOG_FILE
done < $DBTEMPFILE

#exit   # uncomment just for testing download set-up

echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $NAMTOGET ]
  then
   # get the date 1 year ago.  NAM archive only goes back 1 year, so get .inv
   # files from NAMANL (NAM) if before (after) this date
    yyyymmddnow=`date -u +%Y%m%d`
    lastyr_yyyymmdd=`offset_date $yyyymmddnow -365`

   # list and acquire the unique model cycles
    for filespec in `cat $NAMTOGET | cut -f4 -d '|' | sort -u`
      do
       # check whether data date is more than 1 year ago; if so then get .inv
       # from namanl, otherwise get from nam archive
        file_yyyymmdd=`echo $filespec | cut -f2 -d'/'`
        echo "lastyr: $lastyr_yyyymmdd    fileyr: $file_yyyymmdd"
        if [ $file_yyyymmdd -gt $lastyr_yyyymmdd ]
          then
           # generate the matching .inv file name for retrieval from the nam achive
           # since the namanl archive has missing .inv files after late-Sep. 2010
            invfilespec=`echo $filespec | sed 's/namanl/nam/'`
            b="http://nomads.ncdc.noaa.gov/data/nam/${invfilespec}"
          else
            b="http://nomads.ncdc.noaa.gov/data/namanl/${filespec}"
        fi
        echo "Inventory file: $b"
       # generate the output .grb filename prefix
        outfile=`echo $filespec | cut -f3 -d'/'`
        a="http://nomads.ncdc.noaa.gov/data/namanl/${filespec}"
        echo "GRIB file: $a"
#        get_inv.pl $a.inv | egrep ":(TMP|RH):500 mb"  | \
        get_inv.pl $b.inv | egrep "(:(TMP|RH|UGRD|VGRD):[1-9][0-9]* mb)|TMP:sfc|TSOIL:0-10|SOILW:0-10"  | \
        get_grib.pl $a.grb ${GRIB_DATA}/${outfile}.grb

        if [ -s ${GRIB_DATA}/${outfile}.grb ]
          then
            echo "finished downloading ${outfile}.grb" | tee -a $LOG_FILE
            gzip -v ${GRIB_DATA}/${outfile}.grb | tee -a $LOG_FILE 2>&1
            if [ $? = 0 ]
              then
                dbfile=${outfile}.grb.gz
              else
                echo "Error compressing ${outfile}.grb, store as-is." | tee -a $LOG_FILE
                dbfile=${outfile}.grb
            fi
           # find the orbit(s) associated to this model cycle, and catalog in DB
            for orbitfile in `grep $filespec $NAMTOGET`
              do
                orbit=`echo $orbitfile | cut -f1 -d '|'`
                dbdate=`echo $orbitfile | cut -f2 -d '|'`
                dbcycle=`echo $orbitfile | cut -f3 -d '|'`
                echo "insert into modelgrids(orbit,cycle,model,filetype,filename) values \
 (${orbit}, '${dbdate} ${dbcycle}', 'NAMANL', 'GRIB', '${dbfile}');" \
 | psql gpmgv  | tee -a $LOG_FILE 2>&1
            done
          else
            echo "ERROR -- File ${outfile}.grb not downloaded!" | tee -a $LOG_FILE
        fi

    done
fi

exit
