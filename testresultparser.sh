#!/bin/bash
# shellcheck disable=2034

for dir in $1; do
    echo "now applying to $dir"

    SUMMARYFILE=$(find "$dir" -name "*run-summary.dat")
    RPATH=$(grep "POS files location" "$SUMMARYFILE" | cut -c 24-)
    read -r -a NODES <<< "$(grep 'Nodes' "$SUMMARYFILE" | cut -c 13-)"

    EXPERIMENT=$(grep "Experiment = " results/2022-09-12_20-27-08/E35-run-summary.dat | cut -c 18-)

    read -r -a FIELDPROTOCOLS <<< "$(grep 'Field  =' "$SUMMARYFILE" | cut -c 16-)"
    read -r -a RINGPROTOCOLS <<< "$(grep 'Ring   =' "$SUMMARYFILE" | cut -c 16-)"
    read -r -a BINARYPROTOCOLS <<< "$(grep 'Binary =' "$SUMMARYFILE" | cut -c 16-)"
    
    CDOMAINS=()
    # activate computation domain for later handling
    [ "${#FIELDPROTOCOLS[*]}" -gt 0 ] && CDOMAINS+=( FIELD )
    [ "${#RINGPROTOCOLS[*]}" -gt 0 ] && CDOMAINS+=( RING )
    [ "${#BINARYPROTOCOLS[*]}" -gt 0 ] && CDOMAINS+=( BINARY )

    EXPORTPATH="${dir::15}/${dir:16}"

    sleep 1s
done

