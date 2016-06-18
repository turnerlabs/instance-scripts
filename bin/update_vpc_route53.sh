#!/bin/bash

# I am an EC2 Instance.
# I live in a VPC
# I have a tag called Name which I want in the VPC Private hosted zone
# I have an instance profile with permission to the VPC Private hosed zone
# I know my internal address from instance data

# Get my local address
a_record=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

# Get my instance ID so I can get my tags
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

# Get my region so I know what API endpoint to talk to
REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//'`

current_fqdn=`curl -s http://169.254.169.254/latest/meta-data/hostname`

current_hostname=`echo $current_fqdn | awk -F\. '{print $1}' `
vpc_zone=`echo $current_fqdn | sed s/$current_hostname.//g`

# get my "Nmae" tag
dnsname=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --query "Tags[?Key=='Name'].{Value:Value}" --output=text | tr '[:upper:]' '[:lower:]'`


if [ $? -ne 0 ] || [ -z "$dnsname" ] ; then
  echo "unable to find dnsname tag. Don't know how to proceed. Aborting...."
  exit 1
fi


echo "Updating $dnsname in $vpc_zone to $a_record"

# Get the zone ID
zone_id=`aws route53 list-hosted-zones --query "HostedZones[?Name=='${vpc_zone}.'].{Private:Config.PrivateZone,Id:Id}" --output=text | grep True | awk '{print $1}'`
echo $zone_id

if [ -z "$zone_id" ] ; then
  echo "zone ${zone} is not in route 53, or your Instance Role isn't working."
  exit 1
fi

FILE=/tmp/update_file.$$.json
cat > $FILE <<EOM
{
  "Comment": "A new record set for the zone.",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${dnsname}.${vpc_zone}.",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${a_record}"
          }
        ]
      }
    }
  ]
}
EOM

aws route53 change-resource-record-sets --hosted-zone-id $zone_id --region $REGION --change-batch file://$FILE
if [ $? -eq 0 ] ; then
  rm $FILE
  echo "Success!"
  exit
else
  exit 1
fi
