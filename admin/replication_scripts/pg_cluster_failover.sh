#!/bin/bash
#
#
#title           :pg_cluster_failover.sh
#description     :This script will perform a Failover of a PostgreSQL-Replication- and metasfresh_server-Cluster
#author          :J.Bischof (julian.bischof@metasfresh.de) 
#date            :2015-10-26
#version         :0.1    
#usage           :/bin/bash pg_cluster_failover.sh
#notes           :Uses "eth0:1" on App- and PG-Server as virtual device
#                 Only performs the failover for metasfresh service and PostgreSQL-Cluster - You
#		  need to add additional scripts to the ./post_failover_scripts directory.
#		  When adding additional scripts to the directory, use a number as affix to determine the
#		  order of the scripts ("10_myfirstscript" runs before "20_mysecondscript")
#                 Local user "root" REQUIRES ssh-access to the Primary and Failover Server's "root" user.
#dependencies    :GNU bash (tested with v.4.2.25(1))
#		 :OpenSSH (tested with v.5.9p1)
#==============================================================================



SR_PRIMARY=                             #set hostname for PostgreSQL Primary Server
APP_PRIMARY=                            #set hostname for live metasfresh-app-server
APP_FAILOVER=                           #set hostname for failover metasfresh-app-server
PG_DB_PATH=/var/lib/postgresql/9.1/main #set path to PostgreSQL-Binaries
SMX_PATH=/opt/apache-servicemix-4.5.1   #set path to servicemix on app-servers
SCRIPT_DIR=/root/replication_scripts    #set path to folder where this script is located

#Do not set the next two vars
PG_RUNNING=NOTSET
SR_IS_STANDBY=NOTSET


sanity_check()
{
 #check root
 if [[ "$(id -u)" -ne "0" ]]; then
   echo "[ERROR] This script must be run as root" 1>&2
   exit 1
 fi
}

verify_standby()
{
 #Is a postgresql-server running?
 local pg_running=$(service postgresql status | cut -d ":" -f2 | tr -d '[[:space:]]' )
 local sr_standby_file=$PG_DB_PATH/recovery.conf

 if [[ -z $pg_running ]] || [[ $pg_running == *"down"* ]]; then
        PG_RUNNING="NO"
   else
        PG_RUNNING="YES"
 fi
 
 #PostgreSQL-Server seems to be running. Let's query if it's a Standby-Server
 if [[ $PG_RUNNING == "YES" ]]; then
 # $sr_standby_sql returns "t"rue if System is running as a Standby and "f"alse otherwise
 local sr_standby_sql=$(su postgres -c 'psql -d postgres -t -A -c "select pg_is_in_recovery();"' 2>/dev/NULL)
        if [[ $sr_standby_sql == "t" ]]; then
          SR_IS_STANDBY="YES"
        elif [[ $sr_standby_sql == "f" ]]; then
          SR_IS_STANDBY="NO"
        fi
 elif [[ $PG_RUNNING == "NO" ]]; then
        if [[ -f $sr_standby_file ]]; then
          SR_IS_STANDBY="YES"
        else
          SR_IS_STANDBY="NO"
        fi
 fi
}

ssh_access_check()
{
 #check ssh-access:
 ping -c 3 $APP_FAILOVER > /dev/null 2>&1
 if [[ "$?" -eq "0" ]]; then
   ssh -q root@$APP_FAILOVER exit
   if [[ "$?" -eq "0" ]]; then
     APP_FAILOVER_UP=YES
   else
     echo "[ERROR] Cannot connect to App-Server - $APP_FAILOVER - "
     echo "        Exiting without changes ... "
     exit 1
   fi
 else
   echo "[ERROR] Cannot connect to App-Server - $APP_FAILOVER - "
   echo "        Exiting without changes ... "
   exit 1
 fi

 ping -c 3 $SR_PRIMARY > /dev/null 2>&1 
 if [[ "$?" -eq "0" ]]; then
   ssh -q root@$SR_PRIMARY exit
   if [[ "$?" -eq "0" ]]; then
      SR_PRIMARY_UP=YES
   else
      SR_PRIMARY_UP=NO
   fi
 else
   SR_PRIMARY_UP=NO
 fi

 ping -c 3 $APP_PRIMARY > /dev/null 2>&1 
 if [[ "$?" -eq "0" ]]; then
   ssh -q root@$APP_PRIMARY exit
   if [[ "$?" -eq "0" ]]; then
      APP_PRIMARY_UP=YES
   else
      APP_PRIMARY_UP=NO
   fi
 else
   APP_PRIMARY_UP=NO
 fi
}

pre_failover_menu()
{
 echo "

 ====================== Cluster Failover Script ========================
 This script will perform a FAILOVER of an active PostgreSQL-
 Streaming-Replication- and App-Server-Cluster.

 
 DO NOT RUN THIS SCRIPT IF YOU'RE NOT 100% SURE WHAT YOU'RE DOING!


 This script should ALWAYS be run on the Standby-PostgreSQL-Server!
 
 The script will perform following tasks:
 1. Checks if the PRIMARY Servers and the FAILOVER App-Server are
    reachable via ssh 
 2. Checks if this server (localhost) looks indeed like a
    Standby-Server.
 3. Asks for user-input for additional scripts and verification
 4. If available, stops the application (metasfresh) on
    the PRIMARY App-Server, including Servicemix and the virtual
    ethernet-interface \"eth0:1\".
 5. If available, stop the PostgreSQL-Server on the PRIMARY Data-
    base-Server, stores the previous config-files of PostgreSQL and
    applies preconfigured standby-configs. Also disables virtual
    ethernet-interface \"eth0:1\".
 6. Prepares the STANDBY Database-Server (this server), stores the
    previous configs and applies primary-config-files. Enables the
    local virtual ethernet-interface \"eth0:1\".
 7. On the FAILOVER App-Server, enables the virtual ethernet-
    interface \"eth0:1\" and starts the application and if
    available Servicemix.
 8. Performs final checks if everything went fine.
 ========================================================================="


verify_standby

 read -p 'Press [Enter] to continue.'
 echo ""
 echo " ... checking ssh-access ...                     "
 ssh_access_check
 echo ""
 echo ""
 echo " ----------------- Current Setup -----------------"
 echo " PRIMARY DB-Server: $SR_PRIMARY                      "
 echo " PRIMARY App-Server: $APP_PRIMARY                      "
 echo " STANDBY DB-Server: $(hostname)                      "
 echo " STANDBY App-Server: $APP_FAILOVER                      "
 echo " PostgreSQL on STANDBY is running: $PG_RUNNING    "
 echo " recovery.conf location: $PG_DB_PATH/recovery.conf"
 echo " Server appears to be a STANDBY-Server: $SR_IS_STANDBY"
 echo " $SR_PRIMARY SSH available: $SR_PRIMARY_UP		"
 echo " $APP_PRIMARY SSH available: $APP_PRIMARY_UP		"
 echo " $APP_FAILOVER SSH available: $APP_FAILOVER_UP	"
 echo " -------------------------------------------------"
 echo ""
 
 local POST_FAILOVER_FILES=(${SCRIPT_DIR}/post_failover_scripts/*.sh)
 RUN_SR_INIT="NO"
 RUN_POST_SCRIPTS="NO"
 if [[ $SR_PRIMARY_UP == "YES" ]] || ( [[ ! -d "$POST_FAILOVER_FILES" ]] && [[ $(ls -A $POST_FAILOVER_FILES 2>/dev/null | wc -l) -gt "0" ]] ); then
   echo " ---------------- Optional Scripts --------------- "
   if [[ $SR_PRIMARY_UP == "YES" ]]; then
     ssh -q root@$SR_PRIMARY [[ -f ${SCRIPT_DIR}/pg_reinit_standby.sh ]] && SR_INIT_FILE="YES" || SR_INIT_FILE="NO"
     if [[ $SR_PRIMARY_UP == "YES" ]] && [[ $SR_INIT_FILE="YES" ]]; then
       read -p " Reinitialize Streaming-Replication on $SR_PRIMARY ? Yy/Nn : " SR_INIT_PROMPT
       case $SR_INIT_PROMPT in
          [Yy] ) RUN_SR_INIT="YES";;
          [*]  ) RUN_SR_INIT="NO";;
       esac
     fi
   fi
   if [[ ! -d "$POST_FAILOVER_FILES" ]] && [[ $(ls -A $POST_FAILOVER_FILES 2>/dev/null | wc -l) -gt "0" ]]; then
     read -p " Execute additional Shell-Scripts (in ${SCRIPT_DIR}/post_failover_scripts) ? Yy/Nn : " POST_FAILOVER_PROMPT
     case $POST_FAILOVER_PROMPT in
        [Yy] ) RUN_POST_SCRIPTS="YES";;
        [*]  ) RUN_POST_SCRIPTS="NO";;
     esac
   fi
   echo " -------------------------------------------------- "
   echo ""
 fi

 if [[ ! $SR_IS_STANDBY == "YES" ]]; then
   echo "[ERROR] This Server does NOT appear to be a STANDBY Server!"
   echo "        Please check if this Server is configured as a Standby-Server."
   echo "        (Hint: postgresql.conf/recovery.conf)"
   echo "        Exiting without changes ..."
   exit 1
 fi

 while true; do
   read -p "Do you REALLY want to proceed? (final warning) Yy/Nn : " INST_PROMPT
   case $INST_PROMPT in
     [Yy] ) echo "";
            echo "[INFO] Performing failover!"; break;;
     * ) echo "[INFO] Exiting without changes..."; exit 2;;
   esac
 done

}

set_app_primary_down()
{
 ssh -q root@$APP_PRIMARY [[ -f /etc/init.d/metasfresh_server ]] && APP_NAME=metasfresh || APP_NAME=adempiere
 ssh root@$APP_PRIMARY "su servicemix -c \"$SMX_PATH/bin/stop\" "

 if [[ $APP_NAME == "metasfresh" ]]; then
   ssh root@$APP_PRIMARY '/etc/init.d/metasfresh_server stop'
 else
   ssh root@$APP_PRIMARY '/etc/init.d/adempiere_server stop'
 fi

 echo "[INFO] Stopping Virtual Ethernet Adapter 'eth0:1' on $APP_PRIMARY"
 ssh root@$APP_PRIMARY 'ifdown eth0:1'
}

set_pg_primary_down()
{
 echo "[INFO] Stopping PostgreSQL-Server and Virtual Ethernet Adapter 'eth0:1' on $SR_PRIMARY"
 ssh root@$SR_PRIMARY 'service postgresql stop && ifdown eth0:1'
 #Store old configs
 echo "[INFO] Saving old PostgreSQL-Server configs to backup-folder on $SR_PRIMARY"
 ssh -q root@$SR_PRIMARY [[ ! -d "/root/primary-configs/backup" ]] && ssh root@$SR_PRIMARY "mkdir -p /root/primary-configs/backup"
 ssh root@$SR_PRIMARY 'find /etc/postgresql/ -type f -name "postgresql.conf" -exec cp -a {} /root/primary-configs/backup/ \;'
 ssh root@$SR_PRIMARY 'find /etc/postgresql/ -type f -name "pg_hba.conf" -exec cp -a {} /root/primary-configs/backup/ \;'
 #Apply Standby-Configs and recovery.conf
 echo "[INFO] Applying PostgreSQL-Server standby-configs on $SR_PRIMARY"
 ssh root@$SR_PRIMARY 'find /etc/postgresql/ -type f -name "postgresql.conf" -exec cp -a /root/standby-configs/postgresql.conf {} \;'
 ssh root@$SR_PRIMARY 'find /etc/postgresql/ -type f -name "pg_hba.conf" -exec cp -a /root/standby-configs/pg_hba.conf {} \;'
 ssh root@$SR_PRIMARY 'cp -a /root/standby-configs/recovery.conf /var/lib/postgresql/9.*/main/'
}

set_pg_failover_up()
{
 echo "[INFO] Stopping PostgreSQL-Standby-Server on $(hostname)"
 /etc/init.d/postgresql stop
 
 echo "[INFO] Starting Virtual Ethernet Adapter 'eth0:1' on $(hostname)"
 ifup eth0:1
 
 if [[ ! -d "/root/standby-configs/backup" ]]; then
    mkdir -p /root/standby-configs/backup
 fi
 echo "[INFO] Saving old PostgreSQL-Server configs to backup-folder and applying PostgreSQL-Active-Server configs on $(hostname)"
 mv /var/lib/postgresql/9.*/main/recovery.conf /root/standby-configs/backup/
 find /etc/postgresql/ -type f -name "postgresql.conf" -exec cp -a {} /root/standby-configs/backup/ \;
 find /etc/postgresql/ -type f -name "pg_hba.conf" -exec cp -a {} /root/standby-configs/backup/ \;
 find /etc/postgresql/ -type f -name "postgresql.conf" -exec cp -a /root/primary-configs/postgresql.conf {} \;
 find /etc/postgresql/ -type f -name "pg_hba.conf" -exec cp -a /root/primary-configs/pg_hba.conf {} \;
 
 echo "[INFO] Starting PostgreSQL-Active-Server on $(hostname)"
 /etc/init.d/postgresql start
}

set_app_failover_up()
{
 ssh -q root@$APP_FAILOVER [[ -f /etc/init.d/metasfresh_server ]] && APP_NAME=metasfresh || APP_NAME=adempiere
  echo "[INFO] Starting Virtual Ethernet Adapter 'eth0:1' on $APP_FAILOVER
       Waiting 30 seconds before starting $APP_NAME ... "
 ssh root@$APP_FAILOVER "ifup eth0:1"
 sleep 30

 if [[ $APP_NAME == "metasfresh" ]]; then
   ssh root@$APP_FAILOVER '/etc/init.d/metasfresh_server start'
 else
   ssh root@$APP_FAILOVER '/etc/init.d/adempiere_server start'
 fi

   ssh root@$APP_FAILOVER "su servicemix -c \"$SMX_PATH/bin/start\""
}

## remove service from autostart (check for servicemix as well)
## do NOT execute pg_reinit_standby.sh after switch

#wait for initializing
#check if failover is "active-server"
post_failover_scripts()
{
 local POST_SCRIPT_PATH=${SCRIPT_DIR}/post_failover_scripts
 for POST_SCRIPT_FILES in "$POST_SCRIPT_PATH"/*
 do
        if [[ -x $POST_SCRIPT_FILES ]]; then
          echo "
[INFO] Executing $POST_SCRIPT_FILES"
          $POST_SCRIPT_FILES
          echo "
[DONE] Script-Execution $POST_SCRIPT_FILES"
        fi
 done
}

post_failover_report()
{
 echo "

   ====================== Cluster Failover Report ========================
   
   Stopped metasfresh on ${APP_PRIMARY}:                          $APP_PRIMARY_UP !
   Stopped PostgreSQL-Server on ${SR_PRIMARY}:                    $SR_PRIMARY_UP !
   Performed  Reinititialisation of ${SR_PRIMARY} as new STANDBY: $RUN_SR_INIT !
   Executed additional Shell-Scripts:                             $RUN_POST_SCRIPTS !

   !!! Things left to do:"

 if [[ ! $APP_PRIMARY_UP == "YES" ]]; then
 echo "        - Stop metasfresh on ${APP_PRIMARY} when it's back up !
          (You may need to stop servicemix and unmount esb-mounts as well)"
 fi

 if [[ ! $SR_PRIMARY_UP == "YES" ]]; then
 echo "        - Reinitialise $SR_PRIMARY as a STANDBY-Server !
          Login on $SR_PRIMARY when it's back up
          Stop PostgreSQL-Server
          Go to '/root/standby-configs/'
          Replace original postgres-configs with the ones in the folder
          Add 'recovery.conf' from 'standby-configs' folder to 'main' folder of
          PostgreSQL (eg. /var/lib/postgresql/9.1/main/)
          Run Reinitialise-Script '/root/replication_scripts/pg_reinit_standby.sh'"
 fi
 echo "        - Test Access via Terminal Server, Web-Interface or Client !
 ========================================================================= 
"

}


main()
{
 sanity_check
 
 pre_failover_menu
 
 if [[ $APP_PRIMARY_UP == "YES" ]]; then
   set_app_primary_down
 fi
 
 if [[ $SR_PRIMARY_UP == "YES" ]]; then
   set_pg_primary_down
 fi
 
 set_pg_failover_up
 
 set_app_failover_up
 
 if [[ $RUN_POST_SCRIPTS == "YES" ]]; then
  post_failover_scripts
 fi
 
 if [[ $RUN_SR_INIT == "YES" ]]; then
  echo "

"
  ssh -t root@$SR_PRIMARY bash "$SCRIPT_DIR/pg_reinit_standby.sh"
  echo "

"
 fi

 post_failover_report
}

main

exit 0


