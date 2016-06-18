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
aws s3 cp /etc/chef/client.pem $PEM_PATH