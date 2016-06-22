#!/bin/bash
#
#
#title           :pg_reinit_standby.sh
#description     :This script will reinitialize a PostgreSQL Streaming-Replication
#                 Standby-Server.
#author		 :J.Bischof (julian.bischof@metasfresh.com) 
#date            :2015-07-23
#version         :0.1    
#usage		 :/bin/bash pg_reinit_standby.sh
#notes           :Please modify variables below to your needs.
#		  If you're also using WAL-Archives for backups, create a backup BEFORE running this script.
#                 Local user "postgres" NEEDS ssh-access to the Primary Server's "postgres" user.
#dependencies    :rsync (tested with v. 3.0.9)
#                 GNU bash (tested with v.4.2.25(1))
#==============================================================================




SR_PRIMARY=                             #Set hostname to your PostgreSQL-Primary-Server
PG_DB_PATH=/var/lib/postgresql/9.1/main #Set Path to your database-directory.
PG_WAL_PATH=/var/wal_archive            #Set Path where you store the wal-archives

#Used for "pg_start_backup('backup_YY-mm-dd')
CURRENT_DATE=`date +%Y-%m-%d`

#Do not set the next two vars
PG_RUNNING=NOTSET
SR_IS_STANDBY=NOTSET


sanity_check()
{
 #Is user "root"?
 if [[ "$(id -u)" -ne "0" ]]; then
   echo "This script mus be run as root" 1>&2
   exit 1
 fi
 
 #Does localhost have the same hostname as the Primary-Server (you're insane?)
 if [[ "$(hostname)" == $SR_PRIMARY ]]; then
   echo "Do NOT run this script on $SR_PRIMARY! Check configs!"
   exit 1
 fi

 echo " ================ Re-Initialise PostgreSQL-Standby Script ================
 This script is used on a broken/inactive PostgreSQL Streaming-Replication
 Standby-Server in order to reinitialize the Standby.

 This script should ALWAYS be run on the Standby-Server.
 
 The script will perform following tasks:
 1. Checks if this server (localhost) looks indeed like a
    Standby-Server and if necessary stops the PostgreSQL-Server
 2. Removes ALL Database-Files, including the WAL-Archive
 3. Sets a manual backup-checkpoint on the PRIMARY Server
    using \"select pg_start_backup('backup_$CURRENT_DATE');\"
 4. Copies all necessary Database-Files from the PRIMARY Server
    to the STANDBY Server (localhost)
 5. Releases the backup-checkpoint on the PRIMARY Server
    using \"select pg_stop_backup();\"
 6. Reinitialises the recovery.conf file
 7. Starts the PostgreSQL-Server on the STANDBY Server (localhost)
 8. Checks, if the PostgreSQL-Server is running without errors

 ========================================================================="

 #Details further down
 verify_standby

 read -p 'Press [Enter] to continue.'
 echo ""
 echo ""
 echo " ----------------- Current Setup -----------------"
 echo " PRIMARY Server: $SR_PRIMARY                      "
 echo " STANDBY Server: $(hostname)                      "
 echo " PostgreSQL on STANDBY is running: $PG_RUNNING    "
 echo " recovery.conf location: $PG_DB_PATH/recovery.conf"
 echo " Server appears to be a STANDBY-Server: $SR_IS_STANDBY"
 echo " -------------------------------------------------"
 echo ""

 #No forcing yet. If the script does not detect the localhost as a Standby-Server, it will not proceed
 if [[ ! $SR_IS_STANDBY == "YES" ]]; then
   echo "This Server does NOT appear to be a STANDBY Server!"
   echo "Please check if this Server is configured as a Standby-Server."
   echo "(Hint: postgresql.conf/recovery.conf)"
   echo "Exiting without changes ..."
   exit 1
 fi

 while true; do
   read -p "Do you REALLY want to proceed? (final warning) Yy/Nn : " INST_PROMPT
   case $INST_PROMPT in
     [Yy] ) echo "";
            echo "[INFO] Starting re-initializing the STANDBY-Server"; break;;
     * ) echo "Exiting without changes..."; exit 2;;
   esac
 done
}


reinit_standby()
{
 echo ""
 if [[ $PG_RUNNING == "YES" ]]; then
   echo "[INFO] Stopping PostgreSQL-Server on STANDBY..."
   /etc/init.d/postgresql stop
 fi
 
 #Saving recovery.conf because we're deleting the whole postgres-main directory
 echo "[INFO] Saving recovery.conf to /var/lib/postgresql/recovery.conf ..."
 cp -a $PG_DB_PATH/recovery.conf /var/lib/postgresql/
 echo "[INFO] Deleting Database and WAL-Archive on STANDBY..."
 rm -r $PG_DB_PATH/*    #delete contents of "main" directory
 rm -r $PG_WAL_PATH/*   #delete remaining wal-archive-files
 echo "[INFO] Starting Base-Backup from $SR_PRIMARY to STANDBY."
 echo "       This may take a long time, depending on the Database-Size. Time for a coffee (or two, or three) ... "
 #This will set a checkpoint on the Primary
 su postgres -c 'ssh postgres@'$SR_PRIMARY' "psql -c \"SELECT pg_start_backup( '\''backup_$CUSTOM_DATE'\'' );\" "'
 #Copies "main"-files from Primary to localhost 
 su postgres -c "rsync -rae ssh postgres@$SR_PRIMARY:$PG_DB_PATH/* $PG_DB_PATH --exclude \"pg_xlog\" "
 #Release checkpoint on Primary
 su postgres -c 'ssh postgres@'$SR_PRIMARY' "psql -c \"SELECT pg_stop_backup();\" "'
 echo "[INFO] Moving recovery.conf back to $PG_DB_PATH and starting PostgreSQL-Server on STANDBY ..."
 mv /var/lib/postgresql/recovery.conf $PG_DB_PATH/
 
 #Recreate pg_xlog on Standby. You may want to change this. 
 if [[ ! -d "$PG_DB_PATH/pg_xlog" ]]; then
   echo "[INFO] Recreating pg_xlog directory"
   mkdir -m 700 "$PG_DB_PATH/pg_xlog"
   chown -R postgres:postgres "$PG_DB_PATH/pg_xlog"
 fi

 /etc/init.d/postgresql start

}

verify_standby()
{
 #Is a postgresql-server running?
 local pg_running=$(service postgresql status | cut -d ":" -f2 | tr -d '[[:space:]]' )
 local sr_standby_file=$PG_DB_PATH/recovery.conf

 if [[ -z $pg_running ]]; then
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

post_init_check()
{
 echo ""
 echo "[INFO] Testing, if everything worked accordingly..."
 echo "       Waiting 30sec for the PostgreSQL-Server to fully boot up"
 #Just to give some slower disks and a huge Database some time to initialize properly
 sleep 30
 verify_standby
 if [[ $PG_RUNNING == "YES" ]] && [[ $SR_IS_STANDBY == "YES" ]]; then
   echo "[SUCCESS] Re-Initialization seems to have worked properly."
   echo "Exiting ..."
   exit 0
 else
   #Maybe we need to wait a bit more?
   sleep 10
   verify_standby
   if [[ $PG_RUNNING == "YES" ]] && [[ $SR_IS_STANDBY == "YES" ]]; then
     echo "[SUCCESS] Re-Initialization seems to have worked properly."
     echo "Exiting ..."
     exit 0
   else 
     echo "[ERROR] Not able to check if Server is in STANDBY-Mode."
     echo "        Please check manually."
     echo "[DEBUG] PG_RUNNING=$PG_RUNNING"
     echo "        SR_IS_STANDBY=$SR_IS_STANDBY"
     echo "        SR_PRIMARY=$SR_PRIMARY"
     echo "        CURRENT_DATE=$CURRENT_DATE"
     echo "        PG_DB_PATH=$PG_DB_PATH"
     echo "        PG_WAL_PATH=$PG_WAL_PATH"
     exit 1
   fi
 fi
}

sanity_check
reinit_standby
post_init_check

exit 0
