#!/bin/bash

#title           :rollout_save_report.sh
#description     :This script will save all report.properties files to a temporary
#                 folder on first run and restore those files on a second run.
#                 The script is intended to be run manually two times:
#                   1. BEFORE a rollout
#                   2. AFTER the rollout
#
#author          :julian.bischof@metasfresh.com
#date            :2017-03-31
#usage           :./rollout_save_report.sh
#==============================================================================


set -e


DIR_ORIG_BASE=/opt/metasfresh/reports
DIR_TEMP_BASE=~/.temp_reports
FILE_NAME_SAVE=report\.properties


if [[ -d ${DIR_TEMP_BASE} ]]; then
    rsync -ar --include="${FILE_NAME_SAVE}" --include='*/' --exclude='*' ${DIR_TEMP_BASE}/ ${DIR_ORIG_BASE}/
    echo "[INFO] Transferred ${FILE_NAME_SAVE} files from ${DIR_TEMP_BASE} to ${DIR_ORIG_BASE}"
    rm -r ${DIR_TEMP_BASE}
    exit 0
else
    mkdir ${DIR_TEMP_BASE}
    rsync -ar --include="${FILE_NAME_SAVE}" --include='*/' --exclude='*' ${DIR_ORIG_BASE}/ ${DIR_TEMP_BASE}/
    echo "[INFO] Transferred ${FILE_NAME_SAVE} files from ${DIR_ORIG_BASE} to ${DIR_TEMP_BASE}"
    exit 0
fi


