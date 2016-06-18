#!/bin/bash

# I am an EC2 Instance.
# I have a tag called chef_runlist. I might also have tags called chef_organization and chef_environment
# I have an instance profile with permission to an artifact bucket

# Get my instance ID so I can get my tags
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

# Get my region so I know what API endpoint to talk to
REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//'`

if [ -z "$INSTANCE_ID" ] || [ -z "$REGION" ]  ; then
  echo "I have no instance-id or region. Am I an AWS Instance? "
  exit 1
fi


# get my "chef_*" tags
CHEF_ORGANIZATION=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --query "Tags[?Key=='chef_organization'].{Value:Value}" --output=text`
if [ $? -ne 0 ] || [ -z "$CHEF_ORGANIZATION" ] ; then
  echo "unable to find chef_organization tag. Don't know how to proceed. Aborting...."
  exit 1
fi

CHEF_BUCKET=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --query "Tags[?Key=='deploy_bucket'].{Value:Value}" --output=text`
if [ $? -ne 0 ] || [ -z "$CHEF_BUCKET" ] ; then
  echo "unable to find deploy_bucket tag. Don't know how to proceed. Aborting...."
  exit 1
fi

CHEF_RUNLIST=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --query "Tags[?Key=='chef_runlist'].{Value:Value}" --output=text`
if [ $? -ne 0 ] || [ -z "$CHEF_RUNLIST" ] ; then
  echo "unable to find chef_runlist tag. Don't know how to proceed. Aborting...."
  exit 1
fi

CHEF_ENVIRONMENT=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --query "Tags[?Key=='chef_environment'].{Value:Value}" --output=text`
if [ -z "$CHEF_ENVIRONMENT" ] ; then
  CHEF_ENVIRONMENT="_default"
fi



# This will fetch the correct client.rb, validator pem, or client.pem (if the client has already registered)
/opt/instance-scripts/bin/get_my_chef_client_pem.sh $CHEF_BUCKET $CHEF_ORGANIZATION $INSTANCE_NAME 

# Now run chef
chef-client --force-formatter -r $CHEF_RUNLIST -E $CHEF_ENVIRONMENT | tee /var/log/chef_run.log


# Save the client.pem back into the bucket so the next instance can get it
/opt/instance-scripts/bin/save_my_chef_client_pem.sh $CHEF_BUCKET $CHEF_ORGANIZATION $INSTANCE_NAME


