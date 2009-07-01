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

SUFFIX=${3}
WORKDIR=${2}/stats
OUTPUTFILE=$WORKDIR/stats.$SUFFIX/stats.$SUFFIX
BG_CONTROL=${4}

function run_bg {
    RUNCOMMAND=$1
    STDOUT=$2
    STDERR=$3


    ${RUNCOMMAND} > ${STDOUT} 2> ${STDERR} &
    COMMAND_PID=$!
    
    echo ${COMMAND_PID} ${RUNCOMMAND} >> ${BG_CONTROL}
}

function kill_bg {
    for PID in `cat ${BG_CONTROL} | awk '{printf $1 " "}'`; do
	kill ${PID}
    done
}

#
#----------------- START section -----------------
# Code section that handles starting of external processes.
#

if [ "$1" = "START" ]; then
    #
    # place commands to start performance monitoring utilities as
    # background processes here.
    #

    rm ${BG_CONTROL}

    if [ ! -d $WORKDIR ]; then
	mkdir $WORKDIR
	chmod 777 $WORKDIR
    fi
    
    if [ ! -d $WORKDIR/stats.$SUFFIX ]; then
	mkdir $WORKDIR/stats.$SUFFIX
	chmod 777 $WORKDIR/stats.$SUFFIX
    fi
    
        # Timestamp before
    echo "<<<<<<<<<<BEFORE>>>>>>>>>>: " > ${OUTPUTFILE}
    date >> ${OUTPUTFILE}
    /bin/netstat -i > ${OUTPUTFILE}-interfaces &
    cat /proc/slabinfo > ${OUTPUTFILE}-slabinfo &
    
    if [ -e /proc/net/rpc/nfs ]; then
	cat /proc/net/rpc/nfs > ${OUTPUTFILE}-nfs_stats &
    fi 
    
    if [ -e /proc/net/rpc/nfsd ]; then
	cat /proc/net/rpc/nfsd > ${OUTPUTFILE}-nfsd_stats &
    fi
    
    run_bg "vmstat 2" ${OUTPUTFILE}-vmstat /dev/null
    run_bg "iostat -x 2" ${OUTPUTFILE}-iostat ${OUTPUTFILE}-iostat

    exit 0
fi

#
#----------------- DONE section -----------------
# Code section that handles stopping of external processes.
#
if [ "$1" = "DONE" ]; then
        #
        # place commands to stop performance monitoring utilities as
        # background processes here.
        #
        
    kill_bg
# Timestamp after
    echo "AFTER: " >> ${OUTPUTFILE} 
    date >> ${OUTPUTFILE} 
    /bin/netstat -i >> ${OUTPUTFILE}-interfaces &
    cat /proc/slabinfo >> ${OUTPUTFILE}-slabinfo &
    
    if [ -e /proc/net/rpc/nfs ]; then
	cat /proc/net/rpc/nfs >> ${OUTPUTFILE}-nfs_stats &
    fi
    
    if [ -e /proc/net/rpc/nfsd ]; then
	cat /proc/net/rpc/nfsd >> ${OUTPUTFILE}-nfsd_stats &
    fi
    
    exit 0
fi

if [ "$1" = "KILL" ]; then
    kill_bg
fi
