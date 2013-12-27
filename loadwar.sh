#!/bin/bash
#
# /etc/init.d/loadwar.sh Loading an S3 stored war file, so tomcat can start with it
#
#
### BEGIN INIT INFO
# Provides: loadwar 
# Required-Start: $local_fs $remote_fs $network 
# Required-Stop: $local_fs $remote_fs $network 
# Should-Start: $named 
# Should-Stop: $named 
# Default-Start: 2 3 4 5 
# Default-Stop: 0 1 6 
# Short-Description: Copy war from SVN. 
# Description: Copy war file needed to the tomcat directory.
### END INIT INFO

set -e 

WAR_NAME=test 
S3CMD=/usr/bin/s3cmd 
WAR_URL=s3://warbasebucket/$WAR_NAME.war 
WEBAPPS_PATH=/srv/apps/webapps

#SVN_COMMAND="svn co svn+ssh://dev@ec2-54-247-12-X.eu-west-1.compute.amazonaws.com/srv/svn/deploys/trunk/pro"
SVN_COMMAND="svn co svn+ssh://developer@ec2-54-247-12-Y.eu-west-1.compute.amazonaws.com//srv/svn/deploys/trunk/pro" 
SVN_PATH="/opt/svn" 
SOURCE_WAR="/opt/svn/pro/application.war" 
RETRIES=300 

if [ `id -u` -ne 0 ]; then
	echo "You need root privileges to run this script"
	exit 1 
fi 

sleep 5 

. /lib/lsb/init-functions 

case "$1" in
	start)
		log_daemon_msg "Starting the copy of the war file [$SOURCE_WAR]"
		export SVN_SSH="ssh -i /opt/svn_pubkey.pem"
		rm -Rf $WEBAPPS_PATH/ROOT $WEBAPPS_PATH/ROOT.war "$SVN_PATH/pro" 2>/dev/null
		cd "$SVN_PATH"
		while [ $RETRIES -gt 0 ]; do
			RETRIES=$(($RETRIES - 1))
			eval "$SVN_COMMAND"
			if [ -f "$SOURCE_WAR" ]; then
				break;
			fi
			sleep 1
		done
		cp "$SOURCE_WAR" "$WEBAPPS_PATH/ROOT.war"
		chown tomcat7.tomcat7 "$WEBAPPS_PATH/ROOT.war"
		log_end_msg 0
		;; 
esac 

exit 0
 
