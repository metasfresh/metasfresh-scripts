#!/bin/bash

#title           :cluster_replication.sh
#description     :This Shell-Script will either start or stop an active streaming
#		  replication, depending on the arguments($1).
#		  "cluster_replication.sh start": 
#				will start the standby server (postgres) and will 
#				reenable and execute the application-sync-script
#		  "cluster_replication.sh stop":
#				will stop the standby server (postgres) and will 
#				disable the application-sync-script
#author          :julian.bischof@metasfresh.com
#date            :2016-06-06
#version         :0.1
#usage           :/bin/bash cluster_replication.sh [start|stop]
#notes           :This script requires an already set up streaming replication
#		  cluster. Also, the target-user ($REP_DB_USER) needs sudo
#		  permissions for "service postgresql [start|stop|status] as well
#		  as a basic "psql" role.
#=================================================================================

set -e


SCRIPT_USER=
REP_DB_USER=
REP_DB_HOST=
SYNC_SCRIPT=

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RUN_MODE=NOTSET

sanity_check(){
 case "$1" in
	start)
		RUN_MODE=START
		;;
	stop)
		RUN_MODE=STOP
		;;
	*)
		echo "[ERROR] Run script with parameter 'start' or 'stop'!"
		echo "        eg.: '/usr/local/bin/cluster_replication.sh stop' to stop replication"
		exit 1
		;;
 esac

 if [[ ! "$(whoami)" == "SCRIPT_USER" ]]; then
	echo "[ERROR] This script needs to be run as user '${SCRIPT_USER}'! Current user = $(whoami) "
	exit 1
 fi
}

check_replication_status(){

 local sr_standby_sql=$(ssh ${REP_DB_USER}@${REP_DB_HOST} 'psql -t -A -c "select pg_is_in_recovery();"' 2>/dev/NULL)
 if [[ $sr_standby_sql == "t" ]]; then
	SR_IS_STANDBY="YES"
 elif [[ $sr_standby_sql == "f" ]]; then
	SR_IS_STANDBY="NO"
 else
	echo "[NOTICE] Could not reliably check if the standby service is running or not!"
	echo "         Please check manually using 'select pg_is_in_recovery();' on the standby server!"
 fi
}

start_replication(){
 echo "[INFO] Starting replication ..."
 ssh ${REP_DB_USER}@${REP_DB_HOST} "sudo service postgresql start"
 echo "[INFO] Testing if replication service is healthy and running ..."
 sleep 10
 check_replication_status
 if [[ "$SR_IS_STANDBY" == "YES" ]]; then
	"[OK] ${REP_DB_HOST} is running and connected to primary server!"
 else
	echo "[NOTICE] ${REP_DB_HOST} does not look like a Standby Server!"
	echo "Please check manually using 'select pg_is_in_recovery();' on the standby server!"
 fi
 echo "[INFO] Enabling Application-Synchronization-Script and executing it!"
 mv ${SYNC_SCRIPT}.tmp ${SYNC_SCRIPT}
 /bin/bash "${SYNC_SCRIPT}"
 echo "[SUCCESS] All done!"
}

stop_replication(){
 if [[ -f ${SYNC_SCRIPT} ]]; then
	echo "[INFO] Disabling Application-Synchronization-Script ..."
	mv ${SYNC_SCRIPT} ${SYNC_SCRIPT}.tmp
 fi

 echo "[INFO] Stopping replication ..."
 ssh ${REP_DB_USER}@${REP_DB_HOST} "sudo service postgresql stop"
 echo "[INFO] Testing if replication service stopped  ..."
 sleep 10
 check_replication_status
 if [[ "$SR_IS_STANDBY" == "NO" ]]; then
   "[SUCCESS] ${REP_DB_HOST} seems to be stopped and not replicating anymore."
 else
   "[ERROR] ${REP_DB_HOST} seems to be still connected to it's primary server!"
   exit 1
 fi
}


main(){
 sanity_check
 case "$RUN_MODE" in
	START)
		start_replication
		;;
	STOP)
		stop_replication
		;;
	*)	
		exit 1
		;;
 esac
}

main
exit 0 
