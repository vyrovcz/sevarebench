#!/bin/bash

#
# framework for running MP-SPDZ programs on TUMI8 testbed environment
# 

source helpers/style_helper.sh
source protocols.sh
source helpers/parameters.sh
source helpers/trap_helper.sh
source helpers/pos_helper.sh

[ "${#@}" -eq 0 ] && usage "no parameters or config file recognized"

echo "setting experiment parameters"
setParameters "$@"

echo "initializing experiment hosts..."
PIDS=()
initializePOS

sleep 2 && echo " ...waiting for initialization"
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "setting experiment hosts..."
PIDS=()
setupExperiment

sleep 2 && echo " ...waiting for setup"
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

RUNSTATUS="${Orange}incomplete${Stop}"

source helpers/testresults_helper.sh

for cdomain in "${CDOMAINS[@]}"; do

    echo "running experiment t1 on hosts... (CDomain $cdomain)"
    PIDS=()
    runExperiment "$cdomain" "t1"

    sleep 2 && echo " ...waiting for experiment"
    for pid in "${PIDS[@]}"; do
        # and error on the testnodes can be caught here
        wait "$pid" || getlastoutput
    done


    echo "running experiment t2 on hosts... (CDomain $cdomain)"
    PIDS=()
    runExperiment "$cdomain" "t2"

    sleep 2 && echo " ...waiting for experiment"
    for pid in "${PIDS[@]}"; do
        # and error on the testnodes can be caught here
        wait "$pid" || getlastoutput
    done


    echo "  done with CDomain $cdomain"

done

RUNSTATUS="${Green}completed${Stop}"
