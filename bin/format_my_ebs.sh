#!/bin/bash

# This script will initialize an empty EBS and mount it on your instance

# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
# This script has some checking to prevent the destruction of an existing volume.
# However it's not warranted to be complete
# USE at your own risk
# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING


DEVICE=$1 	# usually /dev/xvdb
MNT_PT=$2	# usually something like /jenkins

if [ `whoami` != "root" ] ; then
	echo "Run as root/sudo"
	exit 1
fi

if [ -z "$MNT_PT" ] ; then
	echo "Usage: $0 <device> <mountpoint>"
	exit 1
fi

if [ ! -b "$DEVICE" ] ; then
	echo "$DEVICE is not a valid block device"
	exit 1
fi 

PART="${DEVICE}1"

# Make sure this isn't already formatted
CHECK=`file -sL $PART`

if [ "$CHECK" == "${PART}: data" ] ; then
	echo "This looks like a blank disk. Partitioning & formatting"
	parted $DEVICE mklabel gpt
	parted -a optimal $DEVICE mkpart primary 0% 100%
	parted $DEVICE print
	mkfs.ext4 $PART

else
	echo "There is already a filesystem here"
fi

file -sL $PART | grep ext4
if [ $? -ne 0 ] ; then
	echo "Not a valid filesystem or not ext4 which is what I expected. Aborting"
	exit 1
fi
mkdir -p $MNT_PT
echo "$PART 	$MNT_PT		ext4 defaults 0 0 " >> /etc/fstab
mount $MNT_PT
