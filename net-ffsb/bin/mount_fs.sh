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

MNT_FILE="/tmp/net-ffsb.mnt_file"
HOSTNAME=`hostname`
CMND=$1
NET_OPTIONS=$2

CLIENT_MOUNTS=`grep ^${HOSTNAME} ${MNT_FILE} | sed "s/${HOSTNAME}\t//"`

FS=0

for MOUNT in ${CLIENT_MOUNTS}; do

    if [ "${CMND}" = "MOUNT" ]; then
	if [ ! -d /mnt${FS} ]; then
	    if [ -e /mnt${FS} ]; then
		rm -rf /mnt${FS}
	    fi
	    mkdir /mnt${FS}
	fi
    
	if [ -z ${NET_OPTIONS} ]; then
	    mount ${MOUNT} /mnt${FS}
	else
            echo "mount -o ${NET_OPTIONS} ${MOUNT} /mnt${FS}"
	    mount -o ${NET_OPTIONS} ${MOUNT} /mnt${FS}
	fi

	if [ ! -d /mnt${FS}/${HOSTNAME} ]; then
	    mkdir /mnt${FS}/${HOSTNAME}
	fi

    elif [ "${CMND}" = "UMOUNT" ]; then
	sync; sync; sync
	sleep 10
	RETRY=10
#	while [ ${RETRY} -ne 0 ]; do
		umount /mnt${FS}
#		if [ $? -eq 0 ]; then
#			break
#		fi
#	done
#rm -rf /mnt${FS}
    fi

    FS=$(($FS+1))

done
