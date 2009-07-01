#!/bin/sh

 #   Copyright (c) International Business Machines Corp., 2001-2005
 #
 #   This program is free software;  you can redistribute it and/or modify
 #   it under the terms of the GNU General Public License as published by
 #   the Free Software Foundation; either version 2 of the License, or 
 #   (at your option) any later version.
 # 
 #   This program is distributed in the hope that it will be useful,
 #   but WITHOUT ANY WARRANTY;  without even the implied warranty of
 #   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
 #   the GNU General Public License for more details.
 #
 #   You should have received a copy of the GNU General Public License
 #   along with this program;  if not, write to the Free Software 
 #   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

if [ $# -lt 4 ]; then
    echo "Usage: $0 \"<CALLOUT_CMND>\" <THREAD_PER_MOUNT> <FILESET_SIZE> <RUN_TIME>"
    exit
fi

MNT_FILE="/tmp/net-ffsb.mnt_file"
PROF_FILE="/tmp/net-ffsb.current_profile"
HOSTNAME=`hostname`

CALLOUT=$1
THREADS_MNT=$2
FILESET_SIZE=$3
RUN_TIME=$4

CLIENT_MOUNTS=`grep ^${HOSTNAME} ${MNT_FILE} | sed "s/${HOSTNAME}\t//"`
NUM_MNTS=`echo ${CLIENT_MOUNTS} | wc -w | sed 's/^[ \t]*//'`
TOTAL_NUM_MNTS=`cat ${MNT_FILE} | wc -l | sed 's/^[ \t]*//'`
MAX_FILESIZE=`cat ${PROF_FILE} | grep "max_filesize" | sed 's/.*max_filesize\s*=//'`
MIN_FILESIZE=`cat ${PROF_FILE} | grep "min_filesize" | sed 's/.*min_filesize\s*=//'`

#Calculate number of file neede for the fileset size
# FIXME: Realy dumb at the moment, but OK for now.
if [ ${MAX_FILESIZE} -eq ${MIN_FILESIZE} ]; then
    if [ "${MAX_FILESIZE}" != "" ]; then 
    FILE_COUNT=$((${FILESET_SIZE}/${MAX_FILESIZE}/${TOTAL_NUM_MNTS}))
    if [ ${FILE_COUNT} -eq 0 ]; then
	FILE_COUNT=1
    fi
    fi
else
    FILE_COUNT=`cat ${PROF_FILE} | grep "num_files" | sed 's/.*num_files\s*=//'`
    FILE_COUNT=$((${FILE_COUNT}/${TOTAL_NUM_MNTS}))
fi

#Set the number of threads on for the thread group
cat ${PROF_FILE} | sed "s/num_filesystems=[0-9]*/num_filesystems=${NUM_MNTS}/; \
s/num_threads\s*=\s*[0-9]*/num_threads=$((${NUM_MNTS}*${THREADS_MNT}))/" > ${PROF_FILE}-process

#Set the run time
cat ${PROF_FILE}-process | sed "s/time\s*=.*/time=${RUN_TIME}/" > ${PROF_FILE}-tmp
mv ${PROF_FILE}-tmp ${PROF_FILE}-process

#Set the callup script line
if [ "${CALLOUT}" != "" ]; then
    cat ${PROF_FILE}-process | sed "/time=.*/acallout=${CALLOUT}" > ${PROF_FILE}-tmp
    mv ${PROF_FILE}-tmp ${PROF_FILE}-process
fi

#Set the number of initial files
cat ${PROF_FILE}-process | sed "s/num_files\s*=.*/num_files=${FILE_COUNT}/" > ${PROF_FILE}-tmp
mv ${PROF_FILE}-tmp ${PROF_FILE}-process

#Set the filesystems definitions
FS_MNT=0
for MOUNT in ${CLIENT_MOUNTS}; do
    
    if [ ${FS_MNT} -eq 0 ]; then
	#Set the main filesystem definition
	cat ${PROF_FILE}-process | \
	    sed "s/location\s*=.*/location=\/mnt${FS_MNT}\/${HOSTNAME}/" > ${PROF_FILE}-tmp
	mv ${PROF_FILE}-tmp ${PROF_FILE}-process
    else
	#Set the rest of the clone filesystem definitions
	cat ${PROF_FILE}-process | sed '/\[threadgroup0\]/,$d' > ${PROF_FILE}-tmp-fs
	cat ${PROF_FILE}-process | sed -n '/\[threadgroup0\]/,$p' > ${PROF_FILE}-tmp-tg
	echo "[filesystem${FS_MNT}]" >> ${PROF_FILE}-tmp-fs
	echo -e "\tlocation=/mnt${FS_MNT}/${HOSTNAME}" >> ${PROF_FILE}-tmp-fs
	echo "[end${FS_MNT}]" >> ${PROF_FILE}-tmp-fs
	echo >> ${PROF_FILE}-tmp-fs
	cat ${PROF_FILE}-tmp-tg >> ${PROF_FILE}-tmp-fs
	rm ${PROF_FILE}-tmp-tg
	mv ${PROF_FILE}-tmp-fs ${PROF_FILE}-process
    fi
	
    FS_MNT=$((${FS_MNT}+1))

done
