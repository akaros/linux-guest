#!/bin/bash
# 
# Given an existing FS hierarchy at tc_root, this rebuilds the CPIO archive and
# rebuilds Linux with the CPIO attached.
#
# You'll need to run this anytime you manually change the contents of tc_root
# or if you have new kernel modules you'd like to install.

set -e
trap "exit" INT

MAKE_JOBS="${MAKE_JOBS:-8}"
# keep this in sync with the published linux .config.  Must end in .cpio.
INITRD_NAME=akaros/newroot.cpio

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

if [ ! -d "tc_root" ]
then
	echo "tc_root not found, run setup.sh first"
	exit -1
fi

echo "Rebuilding CPIO"

sudo chown -R 1001 tc_root/home/tc

echo "Building Linux modules"
sudo rm -r tc_root/lib/modules/*
rm -rf kernel_mods/
mkdir -p kernel_mods
KERNEL_MODS=`pwd`/kernel_mods
(cd $LINUX_ROOT &&
touch $LINUX_ROOT/$INITRD_NAME &&
make -j $MAKE_JOBS INSTALL_MOD_PATH=$KERNEL_MODS INSTALL_MOD_STRIP=1 modules modules_install
)
sudo cp -r kernel_mods/* tc_root/ || true

echo "Compressing CPIO"
(cd tc_root &&
sudo find . -print | sudo cpio -H newc -o > $LINUX_ROOT/$INITRD_NAME
)

echo "Building Linux with bundled CPIO"
(cd $LINUX_ROOT &&
ARCH=x86_64 make -j $MAKE_JOBS
)
