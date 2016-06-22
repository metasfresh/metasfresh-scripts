#!/bin/bash
#
#
#title           :tunnel_ssh
#description     :This script will create a SSH-Tunnel to an intermediary server.
#author		 :J.Bischof (julian.bischof@metasfresh.com) 
#date            :2016-06-22
#version         :0.2    
#usage		 :/bin/bash tunnel_ssh.sh
#notes           :Please modify variables below to your needs.
#		  This script will run best in a users crontab every minute. This helps when then
#                 customer's ISP dynamically distributes IPs (eg. T-Online)
#                 You need to add the SSH-Public-Key from the executing user to the receiving
#                 user's authorized_keys file and connect at least once.
#==============================================================================

TRGT_USER=
TRGT_HOST=
TRGT_PORT=

 createTunnel() {

   /usr/bin/ssh -N -R ${TRGT_PORT}:localhost:22 ${TRGT_USER}@${TRGT_HOST}
   if [[ $? -eq 0 ]]; then
     echo "Tunnel created!"
   else
     echo "Error in creating tunnel. Code: $?"
   fi
}

 /bin/pidof ssh
 if [[ $? -ne 0 ]]; then
   echo "Creating new tunnel to metas."
   createTunnel
 fi

exit 0