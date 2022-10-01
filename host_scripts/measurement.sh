#!/bin/bash

# Script is run locally on experiment server.

# exit on error
set -e
# log every command
set -x

N2Protocols=( yao yaoO )
#N3Protocols=( replicated-field malicious-rep-field brain ps-rep-field sy-rep-field
#    malicious-rep-ring ps-rep-ring sy-rep-ring replicated-ring malicious-rep-bin
#    ps-rep-bin mal-rep-bmr replicated-bin rep-bmr)
N4Protocols=( rep4-ring )

N3Protocols=( replicated-field malicious-rep-field brain ps-rep-field sy-rep-field
    malicious-rep-ring ps-rep-ring sy-rep-ring replicated-ring malicious-rep-bin
    ps-rep-bin replicated-bin )



REPO_DIR=$(pos_get_variable repo_dir --from-global)
REPO2_DIR=$(pos_get_variable repo2_dir --from-global)
EXPERIMENT=$(pos_get_variable experiment --from-global)
size=$(pos_get_variable input_size --from-loop)
player=$1
cdomain=$2
environ=""
read -r -a protocols <<< "$3"
read -r -a types <<< "$4"
network="$5"
partysize=$6
etype=$7

cd "$REPO_DIR"

{
    echo "player: $player, cdomain: $cdomain, protocols: ${protocols[*]}, types: ${types[*]}"

    # experiment specific part: generate random input
    echo "create $partysize random set of size: $size"
    bash "$REPO2_DIR"/experiments/"$EXPERIMENT"/generatepinput.sh "$size" "$partysize" "$etype"

    # MP-SPDZ specific part: compile experiment
    # only compile if not already compiled
    if [ ! -f Programs/Bytecode/experiment-"$size"-"$partysize"-"$etype"-0.bc ]; then
        case "$cdomain" in
            RING) 
                ./compile.py -R 64 experiment "$size" "$partysize" "$etype";;
            BINARY) 
                ./compile.py -B 64 experiment "$size" "$partysize" "$etype";;
            *) # default to FIELD
                ./compile.py experiment "$size" "$partysize" "$etype";;
        esac
    fi

    # unconcealed verification run
    "$REPO2_DIR"/experiments/"$EXPERIMENT"/experiment.py "$etype"
} > measurementlog"$cdomain"

####
#  environment manipulation section start
####
# shellcheck source=../host_scripts/manipulate.sh
source "$REPO2_DIR"/host_scripts/manipulate.sh

case " ${types[*]} " in
    *" CPUS "*)
        limitCPUs;;&
    *" RAM "*)
        limitRAM;;&
    *" QUOTAS "*)
        setQuota;;&
    *" BANDWIDTHS "*)
        limitBandwidth;;&
    *" LATENCIES "*)
        setLatency;;&
    *" PACKETDROPS "*) # a.k.a. packet loss
        setPacketdrop;;&
     *" FREQS "*)
        setFrequency
esac

####
#  environment manipulation section stop
####

for protocol in "${protocols[@]}"; do

    log=testresults"$cdomain""${protocol::-8}"
    touch "$log"

    success=true

    pos_sync --timeout 300

    # Some protocols are only for 2,3 or 4 parties
    # they imply the flag -N so it's not allowed
    extraflag="-N $partysize"
    # need to skip for some nodes
    skip=false
    if [[ " ${N4Protocols[*]} " == *" ${protocol::-8} "* ]]; then
        extraflag=""
        [ "$player" -lt 4 ] || skip=true
    elif [[ " ${N3Protocols[*]} " == *" ${protocol::-8} "* ]]; then
        extraflag=""
        [ "$player" -lt 3 ] || skip=true
    elif [[ " ${N2Protocols[*]} " == *" ${protocol::-8} "* ]]; then
        extraflag=""
        [ "$player" -lt 2 ] || skip=true
        # yao's -O protocol variant
        if [ "${protocol::-8}" == yaoO ]; then
            protocol=yao-party.x
            extraflag="-O"
        fi
    fi

    # run the SMC protocol
    $skip ||
        /bin/time ./"$protocol" -h 10.10."$network".2 $extraflag -p "$player" \
            experiment-"$size"-"$partysize"-"$etype" &> "$log" || success=false

    pos_upload --loop "$log"

    #abort if no success
    $success

    pos_sync

done

####
#  environment manipulation reset section start
####

case " ${types[*]} " in

    *" FREQS "*)
        resetFrequency;;&
    *" RAM "*)
        unlimitRAM;;&
    *" BANDWIDTHS "*|*" LATENCIES "*|*" PACKETDROPS "*)
    	resetTrafficControl;;&
    *" CPUS "*)
        unlimitCPUs
esac

####
#  environment manipulation reset section stop
####

pos_sync --loop

echo "experiment successful"  >> measurementlog"$cdomain"

pos_upload --loop measurementlog"$cdomain"