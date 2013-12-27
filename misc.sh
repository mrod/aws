#!/bin/bash
SSH_CMD="ssh -i /opt/cmdserver/sshkey.pem -o UserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -oCheckHostIP=no" 
. /opt/aws/source_me.sh 
INDEX=1 

REGION="eu-west-1" 
NAME_PREFIX="Test" 
KEY_PAIR_NAME="TestKPBasic" 
INSTANCE_TYPE="m1.medium" 
SECURITY_GROUP="app-security-group" 
AUTOSCALE_GROUP_NAME="${NAME_PREFIX}ASG" 
AUTOSCALE_CONFIG_NAME="${NAME_PREFIX}ASC" 
AMI_ID="ami-123456" 
QUARTZ_INSTANCE="ec2-54-247-12-34.eu-west-1.compute.amazonaws.com" 
DBUPGRADE_INSTANCE="ec2-46-137-12-45.eu-west-1.compute.amazonaws.com" 
GRACE_PERIOD="380" 

function rescan_instances() {
		echo -n "Retrieving list of AS instances... "
		INSTANCES=$(elb-describe-instance-health instance-pro --region eu-west-1)
		export INSTANCES_URLS
		echo "$INSTANCES" | tr ' ' '\n' | grep -e "^i-" | while read line; do
			INSTANCE_ID=$line
			INSTANCE_URL=$(ec2-describe-instances --region eu-west-1 | grep INSTANCE | grep $INSTANCE_ID | awk '{print $4}')
			if [ -z "$INSTANCES_URLS" ]; then
				INSTANCES_URLS="$INSTANCE_URL"
			else
				INSTANCES_URLS="$INSTANCE_URL,$INSTANCES_URLS"
			fi
			echo "$INSTANCES_URLS" > /opt/cmdserver/instances.txt
		done
		echo "done."
}
case $1 in
	backupdb)
		echo "Backing up production database..."
		$SSH_CMD root@ec2-54-246-103-X.eu-west-1.compute.amazonaws.com bash /usr/local/bin/database_backup.sh
		$SSH_CMD root@ec2-54-246-102-Y.eu-west-1.compute.amazonaws.com bash /usr/local/bin/mongodb_backup.sh
		echo "done"
		;;
	stopall)
		echo "We will stop all instaces."
		as-update-auto-scaling-group $AUTOSCALE_GROUP_NAME --min-size 0 --max-size 0 --region $REGION
		$SSH_CMD root@$QUARTZ_INSTANCE service tomcat7 stop
		echo "All instances shall be stopped now"
		;;
	updateami)
		echo "Changing the AMI in the AS group"
		as-create-launch-config ${AUTOSCALE_CONFIG_NAME}_BAK --image-id $AMI_ID --instance-type $INSTANCE_TYPE --group "$SECURITY_GROUP" --region $REGION --key $KEY_PAIR_NAME
		as-update-auto-scaling-group $AUTOSCALE_GROUP_NAME --launch-configuration ${AUTOSCALE_CONFIG_NAME}_BAK --region $REGION
		as-delete-launch-config ${AUTOSCALE_CONFIG_NAME} --region $REGION
		as-create-launch-config $AUTOSCALE_CONFIG_NAME --image-id $AMI_ID --instance-type $INSTANCE_TYPE --group "$SECURITY_GROUP" --region $REGION --key $KEY_PAIR_NAME
		as-update-auto-scaling-group $AUTOSCALE_GROUP_NAME --launch-configuration ${AUTOSCALE_CONFIG_NAME} --region $REGION
		as-delete-launch-config ${AUTOSCALE_CONFIG_NAME}_BAK --region $REGION
		echo "Completed."
		;;
	softupgrade)
		echo "Updating environment without stopping it"
		$SSH_CMD root@$QUARTZ_INSTANCE service tomcat7 stop
		$SSH_CMD root@$QUARTZ_INSTANCE service loadwar.sh start
		$SSH_CMD root@$QUARTZ_INSTANCE service tomcat7 start
		for INSTANCE in $(as-describe-auto-scaling-instances --region $REGION | awk '{print $2}' | tr '\n' ' '); do
		    as-terminate-instance-in-auto-scaling-group $INSTANCE -D -f --region $REGION
			sleep $(($GRACE_PERIOD * 2))
	    	done
		;;
	dbupgrade)
		echo "Updating the database."
		$SSH_CMD root@$DBUPGRADE_INSTANCE service tomcat7 stop
		$SSH_CMD root@$DBUPGRADE_INSTANCE service loadwar.sh start
		$SSH_CMD root@$DBUPGRADE_INSTANCE service tomcat7 start
		echo "Database is being upgraded right now. Please wait at least $(($GRACE_PERIOD * 2)) seconds to make sure it is completed."
		;;
	startall)
		echo "Now we will start all instances."
		as-update-auto-scaling-group $AUTOSCALE_GROUP_NAME --min-size 2 --max-size 20 --region $REGION
		$SSH_CMD root@$QUARTZ_INSTANCE service loadwar.sh start
		$SSH_CMD root@$QUARTZ_INSTANCE service tomcat7 start
		echo "Everything shall be updated now."
		;;
	status)
		echo "Showing system information"
		as-describe-launch-configs --region $REGION
		as-describe-auto-scaling-groups --region $REGION
		;;
	help)
		echo <<EOF AWS Management script for test $0 [COMMAND] Commands: backupdb\t\tBackups the production DB to S3 stopall\t\tStops all instances in 
production. It is a hard stop. updateami\t\tChanges the AMI to be launched in the AS Group. It shall be specified in the top of the script. softupgrade\t\tUpgrades the 
environment without needing to stop it. EOF
		;; esac
