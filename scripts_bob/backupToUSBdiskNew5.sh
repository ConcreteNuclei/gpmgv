#!/bin/sh
LOG_DIR=/data/logs
LOG_FILE=$LOG_DIR/backupToUSBdiskNew5.log  # perpetual log file?

ymd=`date -u +%Y%m%d`
echo "" | tee -a $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do full backup to USB disk on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

target=/media/usbdisk
ls $target > /dev/null 2>&1
if [ $? != 0 ]
  then
    echo "USB disk off or unmounted.  Exit with failure to do back up." \
    | tee -a $LOG_FILE
    exit
fi

echo "back up the postgres gpmgv database using pg_dump" | tee -a $LOG_FILE

target=/media/usbdisk/data/db_backup
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gpmgvDBdump.gz ]
      then
        mv -v $target/gpmgvDBdump.gz  $target/gpmgvDBdump.old.gz \
         | tee -a $LOG_FILE
    fi
    pg_dump -f /data/tmp/gpmgvDBdump gpmgv | tee -a $LOG_FILE 2>&1
    gzip /data/tmp/gpmgvDBdump | tee -a $LOG_FILE 2>&1
    mv -v /data/tmp/gpmgvDBdump.gz $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

echo "" | tee -a $LOG_FILE
echo " back up the software development area:" | tee -a $LOG_FILE
target=/media/usbdisk/swdev
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/swdev.tar ]
      then
        mv -v $target/swdev.tar  $target/swdev.old.tar | tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /home/morris/swdev.tar  /home/morris/swdev | tee -a $LOG_FILE 2>&1
    mv -v  /home/morris/swdev.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

echo "" | tee -a $LOG_FILE
echo "back up the operational area:" | tee -a $LOG_FILE
dir_orig=`pwd`
cd /home/gvoper
target=/media/usbdisk/gvoper
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gvoperBak.tar ]
      then
        mv -v $target/gvoperBak.tar  $target/gvoperBak.old.tar | tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /tmp/gvoperBak.tar  appdata bin idl scripts | tee -a $LOG_FILE 2>&1
    mv -v  /tmp/gvoperBak.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi
cd $dir_orig

echo "" | tee -a $LOG_FILE
echo " back up the GPM Documents:" | tee -a $LOG_FILE
target=/media/usbdisk/gpm_docs
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gpm_docs.tar ]
      then
        mv -v $target/gpm_docs.tar  $target/gpm_docs.old.tar | tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /home/morris/gpm_docs.tar  /home/morris/GPM_Docs | tee -a $LOG_FILE 2>&1
    mv -v  /home/morris/gpm_docs.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

#echo "" | tee -a $LOG_FILE
#echo " back up e-mail and attachments:" | tee -a $LOG_FILE
#target=/media/usbdisk/morrismail
#mkdir -p $target
#ls $target > /dev/null 2>&1
#if [ $? = 0 ]
#  then
#    if [ -s $target/tbird.tar.gz ]
#      then
#        mv -v $target/tbird.tar.gz  $target/tbird.old.tar.gz \
#	| tee -a $LOG_FILE 2>&1
#    fi
#    tar -cvf  /home/morris/tbird.tar  /home/morris/Attachments \
#              /home/morris/.thunderbird | tee -a $LOG_FILE 2>&1
#    gzip /home/morris/tbird.tar | tee -a $LOG_FILE 2>&1
#    mv -v  /home/morris/tbird.tar.gz  $target | tee -a $LOG_FILE 2>&1
#  else
#    echo "Directory $target not found." | tee -a $LOG_FILE
#    echo "Exit with failure to do back up." | tee -a $LOG_FILE
#    exit
#fi

echo "" | tee -a $LOG_FILE
echo " do /data backups with rsync:" | tee -a $LOG_FILE

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
yend=`echo $ymd | cut -c1-4`

# get YYYYMMDD for 30 days ago, extract year
ymdstart=`offset_date $ymd -30`
ystart=`echo $ymdstart | cut -c1-4`

# after 30 days we will no longer try to back up last year's files, 
# as $ystart will be the current year, the same as $yend
if [ "$ystart" != "$yend" ]
  then
    years="${ystart} ${yend}"
  else
    years=${yend}
fi

echo ""

for yr2do in $years
  do
    echo "Year to do = $yr2do"
done

# ignore year in the following directories, for now
rsync -rtv  /home/data/gpmgv/coincidence_table/ \
     /media/usbdisk/data/coincidence_table | tee -a $LOG_FILE 2>&1

rsync -rtv  /home/data/gpmgv/mosaicimages/archivedmosaic/ \
      /media/usbdisk/data/mosaicimages/archivedmosaic | tee -a $LOG_FILE 2>&1

rsync -rtv  /home/data/gpmgv/prsubsets/ /media/usbdisk/data/prsubsets \
  | tee -a $LOG_FILE 2>&1

# synch up gv_radar for year(s) listed in $years

echo "" | tee -a $LOG_FILE
echo "Back up /home/data/gpmgv/gv_radar" | tee -a $LOG_FILE
echo "Start year = $ystart, End year = $yend" | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

### THESE WILL FAIL WHEN THE TARGET DIRECTORY FOR ${site}/${area}/${year} DOES
### NOT YET EXIST ON THE USB DISK!!!  NEED TO CHECK, AND IF DIRECTORY DOESN'T
### EXIST, DO A mkdir -p TO CREATE IT, OR WORK OUR WAY BACK UP IN THE DIRECTORY
### STRUCTURE.


for site in `ls /home/data/gpmgv/gv_radar/defaultQC_in/`
  do
#    rsync -rtv  /home/data/gpmgv/gv_radar/defaultQC_in/${site}/ \
#         /media/usbdisk/data/gv_radar/defaultQC_in/$site | tee -a $LOG_FILE 2>&1
    for area in `ls /home/data/gpmgv/gv_radar/defaultQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in $years
          do
#            echo "${site}/${area}/${year}:"
#            ls /home/data/gpmgv/gv_radar/defaultQC_in/${site}/${area}/${year}
             rsync -rtv \
               /home/data/gpmgv/gv_radar/defaultQC_in/${site}/${area}/${year}/ \
               /media/usbdisk/data/gv_radar/defaultQC_in/${site}/${area}/${year} \
               | tee -a $LOG_FILE 2>&1
        done
    done
done

for site in `ls /home/data/gpmgv/gv_radar/finalQC_in/`
  do
#    rsync -rtv  /home/data/gpmgv/gv_radar/finalQC_in/${site}/ \
#         /media/usbdisk/data/gv_radar/finalQC_in/$site | tee -a $LOG_FILE 2>&1
    for area in `ls /home/data/gpmgv/gv_radar/finalQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in $years
          do
#            echo "${site}/${area}/${year}:"
#            ls /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}
             rsync -rtv \
               /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}/ \
               /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year} \
               | tee -a $LOG_FILE 2>&1
        done
    done
done

exit
