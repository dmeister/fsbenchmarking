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

if [ -f $1 ]; then
    source $1
else
    echo "No Config file found...  Exiting"
    exit
fi

if [ -z $2 ]; then
    echo "Run has no name....  Exiting"
    exit
else
    RUN_NAME=$2
fi

trap "sig_trap INT" INT
#Extract the hostnames from $CONFIG_CLIENTS and remove duplicate entries.
UNIQ_CLIENTS=`echo ${CONFIG_CLIENTS} | sed 's/:[a-z,A-Z,0-9,\/]*/\n/g;s/ //g' | \
                  sed -n 'G;s/\n/&&/; /^\([ -~]*\n\).*\n\1/d; s/\n//;h;P'`

NUM_CLIENTS=`echo ${UNIQ_CLIENTS} | wc -w`

BG_CTRL=/tmp/stats_bg.file

function launch_work {
    COMMAND=$1
    OUTPUT=$2
    EXIT_STATUS=$3

#echo "Client Execute" $COMMAND $OUTPUT ${EXIT_STATUS}

    CMND_ERR=/tmp/cmnd_error
    CMND_OUT=/tmp/cmnd_out

    $SERVER_NET_CONTROL -n $NUM_CLIENTS -t server -e "$COMMAND" > /dev/null 2>&1 &

    if [ "${OUTPUT}" == "" ]; then
	OUTPUT_FILE=""
    else
	OUTPUT_FILE="-o ${OUTPUT}"
    fi

    for CLIENT in $UNIQ_CLIENTS; do
	$CONFIG_RSH -l $CONFIG_RSH_USER $CLIENT $CLIENT_NET_CONTROL -t client \
	    -h $CONFIG_SERVER ${OUTPUT_FILE} > ${CMND_OUT} 2> ${CMND_ERR} &
    done

    if [ ! "${EXIT_STATUS}" == "" ]; then
	CMND_EXIT=`cat ${CMND_OUT} | grep "Exit Status" | sed 's/Exit Status: //;s/ from .*//'`
	if [ ${EXIT_STATUS} -ne ${CMND_EXIT} ]; then 
	    return 1
	fi
    fi
    wait
    return 0
}

function gen_client_mntfile {

    MNT_FILE="/tmp/net-ffsb.mnt_file"
    echo ${CONFIG_CLIENTS} | sed "s/ /\n/g;s/:/\t${CONFIG_SERVER}:/g"  | sort | uniq > ${MNT_FILE}

    for CLIENT in ${UNIQ_CLIENTS}; do
	${CONFIG_RCP} ${MNT_FILE} ${CONFIG_RSH_USER}@${CLIENT}:/tmp > /dev/null 2>&1
    done
}

function cp_ffsb_profile {

    PROF_FILE=$1

    for CLIENT in ${UNIQ_CLIENTS}; do
	${CONFIG_RCP} ${PROF_FILE} ${CONFIG_RSH_USER}@${CLIENT}:/tmp/net-ffsb.current_profile > /dev/null 2>&1
    done
}

function cleanup {
    echo "Clening up"
    echo "Killing FFSB on client:"
    for CLIENT in ${UNIQ_CLIENTS}; do
	echo -en "\t${CLIENT}"
	PSOUT=`${CONFIG_RSH} -l ${CONFIG_RSH_USER} ${CLIENT} ps aux | grep ffsb 2>/dev/null` 
	while [ "${PSOUT}" != "" ]; do
	    ${CONFIG_RSH} -l ${CONFIG_RSH_USER} ${CLIENT} killall -INT ffsb > /dev/null 2>&1
	    ${CONFIG_RSH} -l ${CONFIG_RSH_USER} ${CLIENT} killall -9 python > /dev/null 2>&1
	    PSOUT=`${CONFIG_RSH} -l ${CONFIG_RSH_USER} ${CLIENT} ps aux | grep ffsb 2>/dev/null`
	    echo -n " . "
	    sleep .5
	done
	echo
    done
    echo "Killing Server Stats"
    ${SERVER_STATS} KILL
    echo "Killing Client Stats"
    launch_work "${CLIENT_STATS} KILL"
    echo "Unmounting Filesystems"
    launch_work "${CLIENT_MNT_CMND} UMOUNT ${MNT_OPTIONS}"
}

function sig_trap {
    echo "Caught SIG${1}"
    if [ "${1}" == INT ]; then
	cleanup
	exit 
    fi
}

function wait_on_setup {
   
    SVR_CTRL_OPT="-n ${NUM_CLIENTS} -t server -p 60001" 

    ${SERVER_NET_CONTROL} ${SVR_CTRL_OPT} \
	-e "${CLIENT_STATS} START ${CLIENT_HOME}/results ${RUN_SUFFIX} ${BG_CTRL}" >/dev/null 2>/dev/null
    echo -e `date` "  :Creating Fileset.\t\t[DONE]"
    echo `date` "  :Starting FFSB."
    ${SERVER_STATS} START ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFFIX} ${PROFILE} ${BG_CTRL} >/dev/null 2>/dev/null
}

function get_results {
    RUN_FFSB_NAME=$1
    RUN_SUFIX=$2

    for CLIENT in ${UNIQ_CLIENTS}; do
	
	if [ ! -d ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFIX}/${CLIENT} ]; then
	    mkdir ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFIX}/${CLIENT}
	fi

	if [ ! -d ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFIX}/${CLIENT}/stats.${PROFILE} ]; then
	    mkdir ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFIX}/${CLIENT}/stats.${PROFILE}
	fi

	${CONFIG_RCP} -r ${CONFIG_RSH_USER}@${CLIENT}:${CLIENT_HOME}/results/*.${RUN_FFSB_NAME} \
	    ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFIX}/${CLIENT} > /dev/null 2>&1
	${CONFIG_RCP} -r ${CONFIG_RSH_USER}@${CLIENT}:${CLIENT_HOME}/results/stats/stats.${RUN_SUFIX}/* \
	    ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFIX}/${CLIENT}/stats.${RUN_FFSB_NAME}  > /dev/null 2>&1
    done
}

function main {

    gen_client_mntfile
    FFSB_PROF="/tmp/net-ffsb.current_profile-process"

    if [ ! -d ${SERVER_HOME}/results/${RUN_NAME} ]; then
	mkdir ${SERVER_HOME}/results/${RUN_NAME}
    fi

    for PROFILE in `ls ${SERVER_HOME}/profiles/`; do
	cp_ffsb_profile ${SERVER_HOME}/profiles/${PROFILE}
	launch_work "$CLIENT_GEN_FFSB_PROF ${CLIENT_CALLOUT} ${CONFIG_THREADS_MNT} ${CONFIG_FILESET_SIZE} ${CONFIG_RUN_TIME}"
	
	
	for PROTOCOL in $CONFIG_SERVER_PROTOCOL; do
	    for VERSION in $CONFIG_VERSION; do
		for RPC_SIZE in $CONFIG_RPC_SIZE; do
		    
		    RUN_SUFFIX="NFSv${VERSION}_${PROTOCOL}_${RPC_SIZE}"
		    MNT_OPTIONS="vers=$VERSION,rsize=$RPC_SIZE,wsize=$RPC_SIZE,$PROTOCOL"
		    
		    EXTRA_OPTIONS="CONFIG_NFSV${VERSION}_OPTIONS"
		    if [ ${!EXTRA_OPTIONS} ]; then
			MNT_OPTIONS="${MNT_OPTIONS},${!EXTRA_OPTIONS}"
		    fi

		    if [ ! -d ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFFIX} ]; then
			mkdir ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFFIX}
		    fi

		    echo "${RUN_SUFFIX}: Running ${PROFILE} profile"
		    echo "========================="
		    
                    echo `date` "  :Mounting Filesystems."
		    launch_work "${CLIENT_MNT_CMND} MOUNT ${MNT_OPTIONS}"
                    echo -e `date` "  :Mounting Filesystems.\t\t[DONE]"
		    
                    echo `date` "  :Sending Create sync."
		    wait_on_setup &
                    echo -e `date` "  :Sending Create sync.\t\t[DONE]"

                    echo `date` "  :Creating Fileset."
		    launch_work "${CLIENT_FFSB} ${FFSB_PROF}" ${CLIENT_HOME}/results/ffsb.${PROFILE}
		    echo -e `date` "  :Starting FFSB.   \t\t[DONE]"
		    echo -e `date` "  :Stoping Stats."
		    ${SERVER_STATS} DONE ${SERVER_HOME}/results/${RUN_NAME}/${RUN_SUFFIX} ${PROFILE} ${BG_CTRL} > /dev/null 2>/dev/null &
		    launch_work "${CLIENT_STATS} DONE ${CLIENT_HOME}/results ${RUN_SUFFIX} ${BG_CTRL}" &
                    wait
                    echo -e `date` "  :Stoping Stats.   \t\t[DONE]"

                    echo `date` "  :Getting results." 
		    get_results ${PROFILE} ${RUN_SUFFIX}
                    echo -e `date` "  :Getting results.   \t\t[DONE]"

                    echo `date` "  :Umounting filesystem."
		    launch_work "${CLIENT_MNT_CMND} UMOUNT ${MNT_OPTIONS}"
                    echo -e `date` "  :Umounting filesystem.\t\t[DONE]"
		    
#echo "Server Execute" ${SERVER_REPORT} -n ${RUN_NAME} -s ${RUN_SUFFIX} -p ${PROFILE} -r ${SERVER_HOME}/results

		    ${SERVER_REPORT} -n ${RUN_NAME} -s ${RUN_SUFFIX} -p ${PROFILE} -r ${SERVER_HOME}/results

		done #RPC_SIZE loop
	    done #VERSION loop
	done #PROTOCOL loop
	
    done #PROFILE loop
}

main
