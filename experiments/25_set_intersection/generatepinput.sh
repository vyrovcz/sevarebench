#!/bin/bash

REPO2_DIR=$(pos_get_variable repo2_dir --from-global)
amount=$1
partysize=$2

echo "create array with of size: $amount"
for i in $(seq 0 $((partysize-1))); do
    "$REPO2_DIR"/helpers/inputgen.py -s "$amount" $((2*partysize*amount)) "$i" > Player-Data/Input-P"$i"-0
done