#!/bin/bash
#
# Helper script - sets up the tc_root, builds the CPIO and guest, and copies
# the guest to various places.
#
# You'll want to customize this for your environment.

usage()
{
	echo "$0 PATH_TO_LINUX_ROOT"
	exit -1
}

if [ $# -lt 1 ]
then
	usage
fi
LINUX_ROOT=$1

./setup.sh

# Do your own stuff here
sudo cp ~/.ssh/db_rsa.pub tc_root/home/tc/.ssh/authorized_keys

./rebuild_cpio_and_linux.sh $LINUX_ROOT


# Copy it wherever you want here
echo "Copying to KFS"
cp $LINUX_ROOT/vmlinux $AKAROS_ROOT/kern/kfs/
echo "Copying to devbox"
scp $LINUX_ROOT/vmlinux devbox:
