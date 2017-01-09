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
sudo cp ~/.ssh/db_rsa.pub tc_root/home/tc/.ssh/
sudo cp ~/.ssh/db_rsa tc_root/home/tc/.ssh/
# This implies the VM is using qemu mode addressing
sudo dd of=tc_root/home/tc/.ssh/config status=none << EOF
Host host
    Hostname 10.0.2.2
    User root
    IdentitiesOnly yes
    IdentityFile ~/.ssh/db_rsa
	StrictHostKeyChecking no
EOF

./rebuild_cpio_and_linux.sh $LINUX_ROOT


# Copy it wherever you want here
echo "Copying to devbox"
scp $LINUX_ROOT/vmlinux devbox:
