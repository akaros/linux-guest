#!/bin/bash
#
# Helper script - sets up the tc_root, builds the CPIO and guest, and copies
# the guest to various places.
#
# You'll want to customize this for your environment.

set -e
trap "exit" INT

# Set this to paths to binaries on your system, however you'd like.
## This is relatively large (15 MB)
#CUSTOM_BINARIES+="$HOME/src/linux/tools/perf/perf"
# TC's taskset is mediocre
CUSTOM_BINARIES+=" "
CUSTOM_BINARIES+=`which taskset`

usage()
{
	echo "$0 NOT_RELATIVE_PATH_TO_LINUX_ROOT"
	exit -1
}

if [ $# -lt 1 ]
then
	usage
fi
LINUX_ROOT=$1

if [[ ${LINUX_ROOT:0:1} == "." ]]
then
	usage
fi

./setup.sh

# Do your own stuff here.  This lets me ssh in and out as either tc or root
sudo mkdir -p tc_root/home/tc/.ssh/
sudo cp ~/.ssh/db_rsa.pub tc_root/home/tc/.ssh/authorized_keys
sudo cp ~/.ssh/db_rsa.pub tc_root/home/tc/.ssh/
sudo cp ~/.ssh/db_rsa tc_root/home/tc/.ssh/

sudo mkdir -p tc_root/root/.ssh/
sudo cp ~/.ssh/db_rsa.pub tc_root/root/.ssh/authorized_keys
sudo cp ~/.ssh/db_rsa.pub tc_root/root/.ssh/
sudo cp ~/.ssh/db_rsa tc_root/root/.ssh/

# This implies the VM is using qemu mode addressing
sudo dd of=tc_root/home/tc/.ssh/config status=none << EOF
Host host
	Hostname 10.0.2.2
	User root
	IdentitiesOnly yes
	IdentityFile ~/.ssh/db_rsa
	StrictHostKeyChecking no
EOF
sudo cp tc_root/home/tc/.ssh/config tc_root/root/.ssh/

for i in $CUSTOM_BINARIES; do
	sudo cp $i tc_root/usr/local/bin/
done
sudo chmod o+rx tc_root/usr/local/bin/*

./rebuild_cpio_and_linux.sh $LINUX_ROOT


# Copy it wherever you want here
echo "Copying to devbox"
scp $LINUX_ROOT/vmlinux devbox:
