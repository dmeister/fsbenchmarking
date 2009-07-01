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

if [ $# -ne 2 ]; then
    echo "Usage: $0 <Config_file> <Run Name>"
    exit
fi

CONFIG_FILE=$1
RUN_NAME=$2

if [ ! -e ${CONFIG_FILE} ]; then
    echo "Error: ${CONFIG_FILE} not found!"
    exit
fi

bin/net-ffsb.sh ${CONFIG_FILE} ${RUN_NAME} | tee results/${RUN_NAME}.log
