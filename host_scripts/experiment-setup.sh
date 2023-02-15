#!/bin/bash

# Experiment setup-script to be run locally on experiment server

# exit on error
set -e
# log every command
set -x

REPO_DIR=$(pos_get_variable repo_dir --from-global)
REPO2_DIR=$(pos_get_variable repo2_dir --from-global)
EXPERIMENT=$(pos_get_variable experiment --from-global)
# SMC protocols to compile
protocols="$1"
ipaddr="$2"
SWAP="$3"
network="$4"
read -r -a nodes <<< "$5"
groupsize=${#nodes[*]}


#######
#### set networking environment
#######

# driver for Intel Network Adapter for E810 100G card
installDriver() {
	wget https://downloadmirror.intel.com/763930/ice-1.10.1.2.2.tar.gz
	tar -xf ice-1.10.1.2.2.tar.gz
	cd ice-1.10.1.2.2/src/
	make install &> makelog || true
	cd ..
	mkdir -p /lib/firmware/updates/intel/ice/ddp/
	cp ddp/ice-1.3.30.0.pkg /lib/firmware/updates/intel/ice/ddp/
	modprobe -r ice
	modprobe ice
}

# If the testnodes are directly connected from NIC to NIC and
# not via a switch, we need to create individual networks for each
# NIC pair and route the network through the correct NIC
# this is not an ideal situation for big party numbers

nic0=$(pos_get_variable "$(hostname)"NIC0 --from-global)
nic1=$(pos_get_variable "$(hostname)"NIC1 --from-global) || nic1=0

ips=()

######
### three nodes indirect connection topology setup
### node 2 --- node 1 --- node 3
### for 25G+ speeds set MTU
if [ "$(hostname | grep -cE "gard|goracle|zone")" -eq 1 ]; then

	# install ddp drivers
	installDriver

	# store other participants ips
	for i in $(seq 2 $((groupsize+1))); do
		[ "$ipaddr" -ne "$i" ] && ips+=( "$i" )
	done

	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic0"
	ip link set dev "$nic0" mtu 9700
	ip link set dev "$nic0" up

	if [ "$ipaddr" -eq 2 ]; then
		# activate forwarding for the center node
		sysctl -w net.ipv4.ip_forward=1
		ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic1"
		ip link set dev "$nic1" mtu 9700
		ip link set dev "$nic1" up
		# route via correct NICs
		ip route add 10.10."$network".3 dev "$nic0"
		ip route add 10.10."$network".4 dev "$nic1"
	# this is probably not required since the routes should be set automatically
	elif [ "$ipaddr" -eq 3 ]; then
		ip route add 10.10."$network".4 via 10.10."$network".2
	else
		ip route add 10.10."$network".3 via 10.10."$network".2
	fi
# three nodes direct connection topology if true
elif [ "$nic1" != 0 ]; then
##### three nodes direct connection topology if true
####if [ "$nic1" != 0 ]; then

	# to achieve high speeds, install ddp drivers
	[ "$(hostname | grep -cE "meld|tinyman|yieldly|gard|goracle|zone")" -eq 1 ] && \
		installDriver

	# verify that nodes array is circularly sorted like
	# --nodes nodeA,nodeB,nodeC or --node nodeC,nodeA,nodeB
	# this is required for the definition of this topology
	
	# specify the ip pair to create the network routes to
	# it's not the ip that is being set to this host
	[ "$ipaddr" -eq 2 ] && ips+=( 3 4 )
	[ "$ipaddr" -eq 3 ] && ips+=( 4 2 )
	[ "$ipaddr" -eq 4 ] && ips+=( 2 3 )

	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic0"
	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic1"

	ip link set dev "$nic0" up
	ip link set dev "$nic1" up

	ip route add 10.10."$network"."${ips[0]}" dev "$nic0"
	ip route add 10.10."$network"."${ips[1]}" dev "$nic1"

	# to achieve high speeds, increase mtu
	[ "$(hostname | grep -cE "meld|tinyman|yieldly|gard|goracle|zone")" -eq 1 ] && {
		ip link set dev "$nic0" mtu 9700
		ip link set dev "$nic1" mtu 9700
	}

# here the testhosts are connected via switch
else
	# support any groupsizes
	# store other participants ips
	for i in $(seq 2 $((groupsize+1))); do
		[ "$ipaddr" -ne "$i" ] && ips+=( "$i" )
	done

	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic0"
	ip link set dev "$nic0" up

fi

# wait for others to finish setup
pos_sync

###
# Networking tests

# don't start test simultaneously
sleep $((ipaddr-2))

# log link test
for ip in "${ips[@]}"; do
	ping -c 5 10.10."$network"."$ip" &>> pinglog || true
done

pos_upload pinglog

# log link test
# shellcheck source=../tools/speedtest.sh
source "$REPO2_DIR"/tools/speedtest.sh

{
	startserver

	for serverip in $(seq 2 $((groupsize+1))); do
		for clientip in $(seq 2 $((groupsize+1))); do
			pos_sync
			# skip the server
			[ "$serverip" -eq "$clientip" ] && continue
			# skip other clients for now
			[ "$ipaddr" -ne "$clientip" ] && continue
			# skip the client server roles repetitions, this is here explicitly and not 
			# merged with case one so that this can be deactivated easily if wanted
			[ "$serverip" -gt "$clientip" ] && continue			

			hostname="${hostname::-1}$serverip"
			echo "measured speed between nodes $((serverip-1)) and $((clientip-1))"
			for k in 1 10; do
					threads="$k"
					echo -e "\n Threads: $k"
					startclient | grep total
			done
		done
	done
} > speedtest

stopserver

pos_upload speedtest


#######
#### compile libaries and prepare experiments
#######


# handle yao's -O protocol Variant
protocols="${protocols//yaoO/yao}"

cp "$REPO2_DIR"/experiments/"$EXPERIMENT"/experiment.mpc \
	"$REPO_DIR"/Programs/Source/
chmod +x "$REPO2_DIR"/helpers/* "$REPO2_DIR"/experiments/"$EXPERIMENT"/*
cd "$REPO_DIR"

tar -xf "$REPO2_DIR"/helpers/SSLcerts.tar

# activate BMR MultiParty
sed -i 's/#define MAX_N_PARTIES 3/\/\/#define MAX_N_PARTIES 3/' BMR/config.h

# add custom compile flags
compflags=$(pos_get_variable compflags --from-global)

if [ "$compflags" != None ]; then
	if [ -f CONFIG.mine ]; then
		sed -i "/^MY_CFLAGS/ s/$/ $compflags/" CONFIG.mine
	else
		echo "MY_CFLAGS += $compflags" >> CONFIG.mine
	fi
fi

# determine the number of jobs for compiling via available ram and cpu cores
maxcoresram=$(($(grep "MemTotal" /proc/meminfo | awk '{print $2}')/(1024*2500)))
maxcorescpu=$(($(nproc --all)-1))
# take the minimum of the two options
maxjobs=$(( maxcoresram < maxcorescpu ? maxcoresram : maxcorescpu ))

# get required packages
make -j "$maxjobs" mpir linux-machine-setup &> makelog

# compiling fails randomly, need to repeat a few times
i=0
maxtry=5
success=false
while [ $i -lt $maxtry ] && ! $success; do
	success=true
	echo "____try $i" >> makelog
	make -j "$maxjobs" $protocols &>> makelog || success=false
	((++i))
	sleep 1
done

# abort if no success
$success

# set up swap disk for RAM pageswapping measurements
if [ -n "$SWAP" ] && [ -b /dev/nvme0n1 ]; then
	echo "creating swapfile with swap size $SWAP"
	parted -s /dev/nvme0n1 mklabel gpt
	parted -s /dev/nvme0n1 mkpart primary ext4 0% 100%
	mkfs.ext4 -FL swap /dev/nvme0n1
	mkdir /swp
	mkdir /whale
	mount -L swap /swp
	dd if=/dev/zero of=/swp/swp_file bs=1024 count="$SWAP"K
	chmod 600 /swp/swp_file
	mkswap /swp/swp_file
	swapon /swp/swp_file
	 # create ramdisk
    totalram=$(free -m | grep "Mem:" | awk '{print $2}')
	mount -t tmpfs -o size="$totalram"M swp /whale
	# preoccupy ram and only leave 16 GiB for faster experiment runs
	# it was observed, that more than that was never required and 
	# falloc is slow in loops on nodes with large ram
	ram=$((16*1024))
	availram=$(free -m | grep "Mem:" | awk '{print $7}')
	fallocate -l $((availram-ram))M /whale/filler
fi

echo "experiment setup successful"

