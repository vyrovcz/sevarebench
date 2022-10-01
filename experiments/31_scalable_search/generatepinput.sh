#!/bin/bash

REPO2_DIR=$(pos_get_variable repo2_dir --from-global)
set_size=$1

echo "create random set with size: $set_size"
"$REPO2_DIR"/helpers/inputgen.py -s "$set_size" $((set_size*2)) "$set_size" > Player-Data/Input-P0-0
"$REPO2_DIR"/helpers/inputgen.py -s 1 $((set_size*2)) $((set_size+1)) > Player-Data/Input-P1-0