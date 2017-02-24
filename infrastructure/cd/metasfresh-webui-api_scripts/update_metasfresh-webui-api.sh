#!/bin/bash

# thx to http://www.davidpashley.com/articles/writing-robust-shell-scripts/
set -o errexit # exit if something fails
set -o nounset # don't allow unset variables

# initialize our artifact URL to the default
ARTIFACT_URL='http://repo.metasfresh.com/service/local/artifact/maven/redirect?r=mvn-master&g=de.metas.ui.web&a=metasfresh-webui-api&v=LATEST'

#
# to learn about getopts, see http://wiki.bash-hackers.org/howto/getopts_tutorial
#
OPTIND=1 # Reset in case getopts has been used previously in the shell.

while getopts "u:" opt; do
    case "$opt" in
    u)  ARTIFACT_URL=$OPTARG
        ;;
    esac
done

# cleanup OPTIND
shift $((OPTIND-1)) 


DEPLOY_DIR=/opt/metasfresh-webui-api
SERVICE_NAME=metasfresh-webui-api

SRC_JAR=${SERVICE_NAME}.jar
TARGET_JAR=${DEPLOY_DIR}/${SERVICE_NAME}.jar

TIME=$(date +"%Y%m%d%H%M")
TARGET_JAR_PREV=${DEPLOY_DIR}/${SERVICE_NAME}-prev.jar


echo "Downloading artifact $ARTIFACT_URL ..."
wget $ARTIFACT_URL -O $SRC_JAR


#echo "------------------------------------------------------------------"
#echo "Artifact info:"
#set +e
#unzip -c $SRC_JAR META-INF/MANIFEST.MF 2>/dev/null
#set -e
#echo "------------------------------------------------------------------"

if [ -e $TARGET_JAR ]; then
	echo Stopping $SERVICE_NAME
	cp -v $TARGET_JAR $TARGET_JAR_PREV
fi

if [ -e /etc/init.d/$SERVICE_NAME ]; then
	echo Stopping $SERVICE_NAME
	/etc/init.d/$SERVICE_NAME stop
else
	echo "/etc/init.d/$SERVICE_NAME does not exist. Please create it. Menawhile, this script does *not* stop the service."
fi

cp -v $SRC_JAR $TARGET_JAR
chmod -v 700 $TARGET_JAR
chown -v metasfresh: $TARGET_JAR


#echo Updating service rc.d
#update-rc.d $SERVICE_NAME defaults

if [ -e /etc/init.d/$SERVICE_NAME ]; then
	echo Starting $SERVICE_NAME
	/etc/init.d/$SERVICE_NAME start
else
	echo "/etc/init.d/$SERVICE_NAME does not exist. Please create it. Menawhile, this script does *not* start the service."
	echo "to create /etc/init.d/$SERVICE_NAME , you can do (as root):"
	echo "		ln -s $TARGET_JAR /etc/init.d/$SERVICE_NAME"
fi


echo "------------------------------------------------------------------"
echo "INSTALLED Artifact info:"
set +e
unzip -c $TARGET_JAR META-INF/MANIFEST.MF 2>/dev/null
set -e
echo "------------------------------------------------------------------"

exit 0
