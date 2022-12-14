#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

dir=$RUN_SCRIPT_DIR/container-data

[ -z $RUN_ROOTLESS ] && RUN_ROOTLESS=0

if [ $RUN_ROOTLESS -eq 1 ]; then
    if [ -d $dir ]; then 
        if [ ! -w $dir ]; then
            __log_message "Restroring permissions of directory '$DATA_DIR' to user '$USER'"
            sudo chown -R $USER:$USER $DATA_DIR
            sudo chmod -R a=,a+rX,u+w,g+w $DATA_DIR
        fi
    fi
fi