#!/bin/bash
# 
# Downloads corepure, extracts it to initramfs, and downloads a few extra
# packages and their deps.  Blows away your old tc_core and cpio.
#
# Once you set up tc_root, you can manually edit files, add packages, or
# whatever, then rebuild_cpio_and_linux.sh.  To add a new TCZ package, it's
# probably easiest to just edit PACKAGES, add any deps, and rerun this script.
# When mucking with tc_root, you'll usually need sudo.  Sorry.
#
# You probably want to set up ssh keys for the TC user, both so you can ssh
# into the VM, as well as so TC can ssh out.  Right now, the server/host keys
# are the same as Akaros's default dropbear server.
#
# TODO: 
# - consider extracting the packages, instead of loading them every run time.
# Needs unsquashfs on the host, extract to tc_root, for example.

SSHD_PORT=23

echo "Downloading TC distro"
wget -q -nc http://tinycorelinux.net/7.x/x86_64/release/distribution_files/corepure64.gz

echo "Extracting TC distro"
sudo rm -rf tc_root
mkdir tc_root
chmod 777 tc_root
(cd tc_root && zcat ../corepure64.gz | sudo cpio -H newc -i)

######## KERNEL SETUP

(cd tc_root &&
sudo rm -f dev/tty1 &&
sudo ln -s hvc0 dev/tty1
)

######## NETWORKING
sudo bash <<EOF
echo 'udhcpc -i eth0 -f &' >> tc_root/opt/bootlocal.sh
EOF

######## PACKAGES

echo "Downloading packages"
mkdir -p tczs
cd tczs

# You can add any other packages you want by default here.  You'll also need to
# add the deps below manually.
PACKAGES='openssl openssh strace apache2.4 libdmapsharing udev-lib liblvm2 parted parted-dev libpcap libusb libnl tcpdump' 

for i in $PACKAGES
do
	wget -q -nc http://tinycorelinux.net/7.x/x86_64/tcz/$i.tcz
done

echo "Extracting packages"

echo "openssl.tcz" > openssh.tcz.dep
echo "openssh.tcz" > tcpdump.tcz.dep
echo "libpcap.tcz" >> tcpdump.tcz.dep
echo "libusb.tcz" >> tcpdump.tcz.dep
echo "libnl.tcz" >> tcpdump.tcz.dep
echo "udev-lib.tcz" >> tcpdump.tcz.dep
cd ..

sudo mkdir -p tc_root/etc/sysconfig/tcedir/optional
sudo cp tczs/* tc_root/etc/sysconfig/tcedir/optional/
sudo chmod +r tc_root/etc/sysconfig/tcedir/optional/*

# This sets up the packages to load at boot time.
for i in $PACKAGES
do
sudo bash <<EOF
echo "su - tc -c 'tce-load -i $i'" >> tc_root/opt/bootlocal.sh
EOF
done

######## SSH

echo "Setting up SSH"

sudo mkdir -p tc_root/usr/local/etc/ssh

# creates our sshd_config
sudo dd of=tc_root/usr/local/etc/ssh/sshd_config status=none << EOF
# This is ssh server systemwide configuration file.
Port $SSHD_PORT
HostKey /usr/local/etc/ssh/ssh_host_rsa_key
ServerKeyBits 1024
LoginGraceTime 600
KeyRegenerationInterval 3600
PermitRootLogin no
StrictModes yes
X11Forwarding no
PrintMotd yes
SyslogFacility AUTH
LogLevel INFO
RSAAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
EOF

# These are the same server keys Akaros uses for its default dropbear setup.
# You can change these later.

# Server rsa key:
sudo dd of=tc_root/usr/local/etc/ssh/ssh_host_rsa_key status=none << EOF
-----BEGIN RSA PRIVATE KEY-----
MIICZQIBAAKBgwCAPaxDQDoR05AF7uaM7FvOMFJoC56HX/7T4bSpjRieqsHXD3r5
wk6xpIlohmlmlz8QSCFl2VamyKFL8JpYnekha6M7+7MiK8bzPb7lqmd+dZCk2/4n
JYNnxjFHv8RRWcX6xvrpqZsVpKzMN+nN6Q26ln31TSfiYAIMqaQFiHNpMY0/AgMB
AAECgYIHx/YyVGzRlRUpjv/VMCg34A23+3CAhU4YfBryqLmEMxc03d8X1Xbh53pg
6brueyHb8ox4OhI8Z3MGARDUbKxvFxtDUgZrXktdJqXvsB+jRPO8JoLybrkWmeP4
QdRqzHWPiqzHKNEbIxfYnPoz+A/W9OOsxniMMSD9iflouy8yPpGdAkIAyMnKBy3L
g7EqtHA6s3dxwyN1K4AxBcP9yRSupvSdMWR+Gnwy82jb+98TUU53z+Cbu85dk+Pe
gO5SuFbIjg53FHsCQgCjgQPBLJB/zzDPZvrFexU/vO+GE++5t0pyTB91to1eODaC
H8j6RnEjR+13s1ipVGmDPnTqs35vRmKTkVrb5TiZDQJCAKDILTXIbwI6WUb545eY
Wwl2mDnIQfkq80sUe7KHiGRn4y7UK3yMiDNNc0uVOQ3F/w7JdleZja/Sp3yjSZ+v
Z52HAkFTiXstm2NIqcc6cFb3xucYZaPLUSxOKsOymgoIznh0ByxyV2ML3Cm56On/
GnbWLParw6FguMyEdeWvl7hgWUENkQJBKzT0azmCC4Par0M8Qns39Y80bxrOxc9z
YZIjPU14FiD1uvOj5e2WxYIjqGj3ttsBYc/cKC7MCH4RHp5smOo0yBU=
-----END RSA PRIVATE KEY-----
EOF
sudo chmod 600 tc_root/usr/local/etc/ssh/ssh_host_rsa_key

# Server rsa pubkey:
sudo dd of=tc_root/usr/local/etc/ssh/ssh_host_rsa_key.pub status=none << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgwCAPaxDQDoR05AF7uaM7FvOMFJoC56HX/7T4bSpjRieqsHXD3r5wk6xpIlohmlmlz8QSCFl2VamyKFL8JpYnekha6M7+7MiK8bzPb7lqmd+dZCk2/4nJYNnxjFHv8RRWcX6xvrpqZsVpKzMN+nN6Q26ln31TSfiYAIMqaQFiHNpMY0/ root@
EOF
sudo chmod 600 tc_root/usr/local/etc/ssh/ssh_host_rsa_key.pub

sudo bash<<EOF
echo '/usr/local/etc/init.d/openssh start' >> tc_root/opt/bootlocal.sh
EOF

######## Tinycore user

sudo mkdir -p tc_root/home/tc
sudo mkdir -p tc_root/home/tc/.ssh
sudo chown -R 1001 tc_root/home/tc
