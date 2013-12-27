#!/bin/bash
#
# recreateRDS.sh Deletes a RDS instance and creates a new one from a given snapshot
#
# Written by Miguel Rodriguez <muybonito@gmail.com>
#

#set -x

case "$1" in
	dev)
		DB_INSTANCE_ID="instance-dev"
		DB_SNAPSHOT_ID="snapshot-01-1"
		echo "Recreating RDS instance for dev environment"
	;;
	sketch)
		DB_INSTANCE_ID="instance-sketch"
		DB_SNAPSHOT_ID="snapshot-01-0"
		echo "Recreating RDS instance for sketch environment"
	;;
	*)
		echo "
AWS RDS recreate script

$0 [COMMAND]

Commands:
dev	Recreates the RDS instance for dev env
sketch	Recreates the RDS instance for sketch env
"
	exit 1
	;;
esac	
	
DB_EC2_REGION="eu-west-1"
PREF_AVAIL_ZONE="eu-west-1a"	
SLEEP_TIME="60"
	
export PATH=$PATH:/home/ec2/bin
export EC2_HOME=/home/ec2
export EC2_URL=https://ec2.eu-west-1.amazonaws.com
# AWS credentials
export AWS_CREDENTIAL_FILE="/apps/dev_platform/.aws/aws-credential-file.txt"
export EC2_PRIVATE_KEY="/apps/dev_platform/.aws/pk-PLJPI7BVQMCAVNDUL3HDEPEPLNK36DQE.pem"
export EC2_CERT="/apps/dev_platform/.aws/cert-PLJPI7BVQMCAVNDUL3HDEPEPLNK36DQE.pem"


# delete DB instance
NOT_DELETED=`rds-describe-db-instances $DB_INSTANCE_ID --region $DB_EC2_REGION | grep -c $DB_INSTANCE_ID`
if [ $NOT_DELETED == 1 ]; then
	echo "Deleting DB instance $DB_INSTANCE_ID ..."
	rds-delete-db-instance $DB_INSTANCE_ID --force --skip-final-snapshot --region $DB_EC2_REGION

	echo "Waiting for $DB_INSTANCE_ID to be deleted..."
	NOT_DELETED=1
	while [ $NOT_DELETED == 1 ]; do
		echo "Waiting..."
		sleep $SLEEP_TIME
		NOT_DELETED=`rds-describe-db-instances $DB_INSTANCE_ID --region $DB_EC2_REGION | grep -c $DB_INSTANCE_ID`
	done
	echo "DB instance $DB_INSTANCE_ID has been deleted"
else
	echo "DB instance $DB_INSTANCE_ID does not exist"
fi


# create new DB instance from snapshot
echo "Creating new DB instance $DB_INSTANCE_ID from snapshot $DB_SNAPSHOT_ID ..."
rds-restore-db-instance-from-db-snapshot $DB_INSTANCE_ID -s $DB_SNAPSHOT_ID -z $PREF_AVAIL_ZONE --region $DB_EC2_REGION
echo "Waiting for $DB_INSTANCE_ID to be created..."
AVAILABLE=0
while [ $AVAILABLE == 0 ]; do
	echo "Waiting..."
	sleep $SLEEP_TIME
	AVAILABLE=`rds-describe-db-instances $DB_INSTANCE_ID --region $DB_EC2_REGION | grep -c available`
done
echo "DB instance $DB_INSTANCE_ID has been created"
