#!/bin/bash


#description	 :This script scans for database-names containing "tmp_*", 
#		  dumps those names into a file and drops the databases listed in that file.
# 		  Best used in combination with a cron-job.
#		  Execute as user "postgres"

#author          :julian.bischof@metasfresh.com
#date            :2017-03-09


set -e

psql -l | grep tmp_ | awk '{print $1}' > /var/lib/postgresql/scripts/drop_tmp_dbs_list
while read in; do dropdb "$in"; done < /var/lib/postgresql/scripts/drop_tmp_dbs_list

exit 0

