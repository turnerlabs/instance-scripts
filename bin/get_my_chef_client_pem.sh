#!/bin/bash

# This script will look for a client pem file in the specified bucket and install it. 
# It's designed to be used with the Sample Chef Deploy template, and supports re-use of the same 
# instance name in the chef server

# this is how is should be called by cfn-init:
# "command": { "Fn::Join": [ "", [ "/opt/instance-scripts/bin/get_my_chef_client_pem.sh ", { "Ref": "pChefConfigBucket"}, 
# 	" ", { "Ref": "pChefOrganization" }, " ", { "Ref": "pInstanceName" } ]]
# },



BUCKET=$1
CHEF_ORG=$2
INSTANCE_NAME=$3

if [ -z "$INSTANCE_NAME" ] ; then
	echo "$0 : Invalid usage"
	exit 1
fi

 
PEM_PATH="s3://${BUCKET}/chef/client.pem/${CHEF_ORG}/${INSTANCE_NAME}"
PEM_KEY="chef/client.pem/${CHEF_ORG}/${INSTANCE_NAME}"
VALIDATOR="s3://${BUCKET}/chef/${CHEF_ORG}/${CHEF_ORG}-validator.pem"
CLIENT="s3://${BUCKET}/chef/${CHEF_ORG}/client.rb"

if [ ! -f /etc/chef/client.pem ] ; then
	# If there is a PEM, we use that. Otherwise, grab the validator
	aws s3api head-object --bucket $BUCKET --key $PEM_KEY --output text
	if [ $? -eq 0 ] ; then
		echo "Using Existing PEM"
		aws s3 cp $PEM_PATH /etc/chef/client.pem
		if [ $? -ne 0 ] ; then
			exit 1
		fi
	else
		echo "Grabbing Validator"
		aws s3 cp $VALIDATOR /etc/chef/${CHEF_ORG}-validator.pem
		if [ $? -ne 0 ] ; then
			exit 1
		fi
	fi
fi



# Also get the client.rb file
if [ ! -f /etc/chef/client.rb ] ; then
	aws s3 cp $CLIENT /etc/chef/client.rb
	if [ $? -ne 0 ] ; then
		exit 1
	fi
fi