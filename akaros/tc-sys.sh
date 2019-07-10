#!/bin/sh
# brho@google.com
# Machine and site-specific runtime configuration/init scripts

# Here's an example of what you can do.  This example is a little hokey for two
# reasons:
# - DHCP may be running, and Akaros's virtio-net NAT will give a response.  We
# kill it if it was already running.  Maybe that's enough.  If you know your
# app/VM won't need dhcp, pass tinycore nodhcp, or override rcS.
# - Akaros's NAT is set up to give 10.0.2.15 for that specific MAC.  Though
# that may change over time, and other VMs may have that same MAC.  YMMV.

NIC=eth0

read MAC < /sys/class/net/eth0/address

if [[ "$MAC" == "00:01:02:03:04:0b" ]]; then
	echo "Detected Akaros Guest, setting up static networking" > /dev/kmsg
	killall udhcpc 2> /dev/null
	ifconfig eth0 up 10.0.2.15 netmask 255.255.255.0 broadcast 10.0.2.25
	route add default gw 10.0.2.2 eth0
	echo "nameserver 8.8.8.8" > /etc/resolv.conf 
else
	echo "Unknown host, turning on DHCP" > /dev/kmsg
	/etc/init.d/dhcp.sh
fi
