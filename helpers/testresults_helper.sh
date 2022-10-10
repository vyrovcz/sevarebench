#!/bin/bash
#### shellcheck disable=SC2076,SC2154

# where we find the experiment results
resultpath="$RPATH/${NODES[0]}/"

# verify testresults
verifyExperiment() {

    # handle yao -O protocol variant, for some reason the result is only at node[1]
    # move to resultpath location
    while IFS= read -r file; do
        mv "$file" "$resultpath"
    done < <(find "$RPATH/${NODES[1]}/" -name "testresultsBINARYyaoO*" -print)

    for cdomain in "${CDOMAINS[@]}"; do
        declare -n cdProtocols="${cdomain}PROTOCOLS"
        for protocol in "${cdProtocols[@]}"; do
            protocol=${protocol::-8}
            
            i=0
            loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            # while we find a next loop info file do
            while [ -n "$loopinfo" ]; do

                # get pos filepath of the measurements for the current loop
                experimentresult=$(find "$resultpath" -name "testresults$cdomain${protocol}_run*$i" -print -quit)
                verificationresult=$(find "$resultpath" -name "measurementlog${cdomain}_run*$i" -print -quit)

                # check existance of files
                if [ ! -f "$experimentresult" ] || [ ! -f "$verificationresult" ]; then
                    styleOrange "  Skip $protocol - File not found error: $experimentresult"
                    continue 2
                fi

                # verify experiment result - call experiment specific verify script
                chmod +x experiments/"$EXPERIMENT"/verify.py
                match=$(experiments/"$EXPERIMENT"/verify.py "$experimentresult" "$verificationresult")
                if [ "$match" != 1 ]; then
                    styleOrange "  Skip $protocol - $match at $experimentresult";
                    continue 2;
                fi
                ((++i))
                loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            done

            # only pass if while-loop actually entered
            [ "$i" -gt 0 ] && okfail ok "  verified - test passed for $protocol"
        done
    done
}

############
# Export experiment data from the pos_upload-ed logs into two tables
############
exportExperimentResults() {

    # set up location
    datatableShort="$EXPORTPATH/data/E${EXPERIMENT::2}_short_results.csv"
    datatableFull="$EXPORTPATH/data/E${EXPERIMENT::2}_full_results.csv"
    mkdir -p "$datatableShort"
    rm -rf "$datatableShort"

    dyncolumns=""
    # get the dynamic column names from the first .loop info file
    loopinfo=$(find "$resultpath" -name "*loop*" -print -quit)
    
    # check if loop file exists
    if [ -z "$loopinfo" ]; then
        okfail fail "nothing to export - no loop file found"
        return
    fi

    for columnname in $(jq -r 'keys_unsorted[]' "$loopinfo"); do
        dyncolumns+="$columnname"
        case "$columnname" in
            freqs) dyncolumns+="(GHz)";;
            quotas|packetdrops) dyncolumns+="(%)";;
            latencies) dyncolumns+="(ms)";;
            bandwidths) dyncolumns+="(Mbs)";;
        esac
        dyncolumns+=";"
    done

    # generate first line of data dump with column information
    echo -e "nodes;program;c.domain;adv.model;protocol;${dyncolumns}runtime(s);maxPhyRAM(MiB)" >> "$datatableShort"
    echo -e "nodes;program;c.domain;adv.model;protocol;comp.intbits;comp.inttriples;comp.vmrounds;${dyncolumns}runtime(s);maxPhyRAM(MiB);P0commRounds;P0dataSent(MB);ALLdataSent(MB);Tx(MB);Tx(rounds);Tx(s);Rx(MB);Rx(rounds);Rx(s);Brcasting(MB);Brcasting(rounds);Brcasting(s);TxRx(MB);TxRx(rounds);TxRx(s);Passing(MB);Passing(rounds);Passing(s);Part.Brcasting(MB);Part.Brcasting(rounds);Part.Brcasting(s);Ex(MB);Ex(rounds);Ex(s);Ex1to1(MB);Ex1to1(rounds);Ex1to1(s);Rx1to1(MB);Rx1to1(rounds);Rx1to1(s);Tx1to1(MB);Tx1to1(rounds);Tx1to1(s);Txtoall(MB);Txtoall(rounds);Txtoall(s);" >> "$datatableFull"
    # nodes info in every row, static
    usednodes="${NODES[*]}" 

    # grab all the measurement information and append it to the datatable
    for cdomain in "${CDOMAINS[@]}"; do
        declare -n cdProtocols="${cdomain}PROTOCOLS"
        for protocol in "${cdProtocols[@]}"; do
            protocol=${protocol::-8}

            advModel=""
            setAdvModel "$protocol"
            i=0
            # get loopfile path for the current variables
            loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            echo "  exporting $protocol"
            # while we find a next loop info file do
            while [ -n "$loopinfo" ]; do
                loopvalues=""
                # extract loop var values
                for value in $(jq -r 'values[]' "$loopinfo"); do
                    loopvalues+="$value;"
                done
                
                # get pos filepath of the measurements for the current loop
                compileinfo=$(find "$resultpath" -name "measurementlog${cdomain}_run*$i" -print -quit)
                runtimeinfo=$(find "$resultpath" -name "testresults$cdomain${protocol}_run*$i" -print -quit)
                if [ ! -f "$runtimeinfo" ] || [ ! -f "$compileinfo" ]; then
                    styleOrange "    Skip - File not found error: runtimeinfo or compileinfo"
                    continue 2
                fi

                ## Minimum result measurement information
                ######
                # extract measurement
                runtime=$(grep "Time =" "$runtimeinfo" | awk '{print $3}')
                maxRAMused=$(grep "maxresident)k" "$runtimeinfo" | awk '{print $6}' | cut -d 'm' -f 1)
                [ -n "$maxRAMused" ] && maxRAMused="$((maxRAMused/1024))"

                # put all collected info into one row (Short)
                echo -e "${usednodes// /,};$EXPERIMENT;$cdomain;$advModel;$protocol;$loopvalues$runtime;$maxRAMused" >> "$datatableShort"

                ## Full result measurement information
                ######
                # extract compile information (this is repeated many times, potential to optimize)
                intbits=$(grep " integer bits" "$compileinfo" | awk '{print $1}')
                inttriples=$(grep " integer triples" "$compileinfo" | awk '{print $1}')
                vmrounds=$(grep " virtual machine rounds" "$compileinfo" | awk '{print $1}')
                compilevalues="${intbits:-NA};${inttriples:-NA};${vmrounds:-NA}"
                # extract extended measurement
                commRounds=$(grep "Data sent =" "$runtimeinfo" | awk '{print $7}')
                dataSent=$(grep "Data sent =" "$runtimeinfo" | awk '{print $4}')
                globaldataSent=$(grep "Global data sent =" "$runtimeinfo" | awk '{print $5}')
                basicComm=${commRounds:-NA};${dataSent:-NA};${globaldataSent:-NA}

                RxMB=$(grep "Receiving directly " "$runtimeinfo" | awk '{print $3}')
                RxRounds=$(grep "Receiving directly " "$runtimeinfo" | awk '{print $6}')
                RxSec=$(grep "Receiving directly " "$runtimeinfo" | awk '{print $9}')
                Rx="${RxMB:-NA};${RxRounds:-NA};${RxSec:-NA}"

                TxMB=$(grep "Sending directly " "$runtimeinfo" | awk '{print $3}')
                TxRounds=$(grep "Sending directly " "$runtimeinfo" | awk '{print $6}')
                TxSec=$(grep "Sending directly " "$runtimeinfo" | awk '{print $9}')
                Tx="${TxMB:-NA};${TxRounds:-NA};${TxSec:-NA}"

                broadcastMB=$(grep "Broadcasting " "$runtimeinfo" | awk '{print $2}')
                broadcastRounds=$(grep "Broadcasting " "$runtimeinfo" | awk '{print $5}')
                broadcastSec=$(grep "Broadcasting " "$runtimeinfo" | awk '{print $8}')
                broadcast="${broadcastMB:-NA};${broadcastRounds:-NA};${broadcastSec:-NA}"

                TxRxMB=$(grep "Sending/receiving " "$runtimeinfo" | awk '{print $2}')
                TxRxRounds=$(grep "Sending/receiving " "$runtimeinfo" | awk '{print $5}')
                TxRxSec=$(grep "Sending/receiving " "$runtimeinfo" | awk '{print $8}')
                TxRx="${TxRxMB:-NA};${TxRxRounds:-NA};${TxRxSec:-NA}"

                passingMB=$(grep "Passing around " "$runtimeinfo" | awk '{print $3}')
                passingRounds=$(grep "Passing around " "$runtimeinfo" | awk '{print $6}')
                passingSec=$(grep "Passing around " "$runtimeinfo" | awk '{print $9}')
                passing="${passingMB:-NA};${passingRounds:-NA};${passingSec:-NA}"

                partBroadcastMB=$(grep "Partial broadcasting " "$runtimeinfo" | awk '{print $3}')
                partBroadcastRounds=$(grep "Partial broadcasting " "$runtimeinfo" | awk '{print $6}')
                partBroadcastSec=$(grep "Partial broadcasting " "$runtimeinfo" | awk '{print $9}')
                partBroadcast="${partBroadcastMB:-NA};${partBroadcastRounds:-NA};${partBroadcastSec:-NA}"

                ExMB=$(grep "Exchanging " "$runtimeinfo" | head -n 1 | awk '{print $3}')
                ExRounds=$(grep "Exchanging " "$runtimeinfo" | head -n 1 | awk '{print $6}')
                ExSec=$(grep "Exchanging " "$runtimeinfo" | head -n 1 | awk '{print $9}')
                Ex="${ExMB:-NA};${ExRounds:-NA};${ExSec:-NA}"

                Ex1to1MB=$(grep "Exchanging one-to-one " "$runtimeinfo" | head -n 1 | awk '{print $3}')
                Ex1to1Rounds=$(grep "Exchanging one-to-one " "$runtimeinfo" | head -n 1 | awk '{print $6}')
                Ex1to1Sec=$(grep "Exchanging one-to-one " "$runtimeinfo" | head -n 1 | awk '{print $9}')
                Ex1to1="${Ex1to1MB:-NA};${Ex1to1Rounds:-NA};${Ex1to1Sec:-NA}"

                Rx1to1MB=$(grep "Receiving one-to-one " "$runtimeinfo" | awk '{print $3}')
                Rx1to1Rounds=$(grep "Receiving one-to-one " "$runtimeinfo" | awk '{print $6}')
                Rx1to1Sec=$(grep "Receiving one-to-one " "$runtimeinfo" | awk '{print $9}')
                Rx1to1="${Rx1to1MB:-NA};${Rx1to1Rounds:-NA};${Rx1to1Sec:-NA}"

                Tx1to1MB=$(grep "Sending one-to-one " "$runtimeinfo" | awk '{print $3}')
                Tx1to1Rounds=$(grep "Sending one-to-one " "$runtimeinfo" | awk '{print $6}')
                Tx1to1Sec=$(grep "Sending one-to-one " "$runtimeinfo" | awk '{print $9}')
                Tx1to1="${Tx1to1MB:-NA};${Tx1to1Rounds:-NA};${Tx1to1Sec:-NA}"
                
                TxtoallMB=$(grep "Sending to all " "$runtimeinfo" | awk '{print $4}')
                TxtoallRounds=$(grep "Sending to all " "$runtimeinfo" | awk '{print $7}')
                TxtoallSec=$(grep "Sending to all " "$runtimeinfo" | awk '{print $10}')
                Txtoall="${TxtoallMB:-NA};${TxtoallRounds:-NA};${TxtoallSec:-NA}"

                measurementvalues="$runtime;$maxRAMused;$basicComm;$Tx;$Rx;$broadcast;$TxRx;$passing;$partBroadcast;$Ex;$Ex1to1;$Rx1to1;$Tx1to1;$Txtoall"

                # put all collected info into one row (Full)
                echo -e "${usednodes// /,};$EXPERIMENT;$cdomain;$advModel;$protocol;$compilevalues;$loopvalues$measurementvalues" >> "$datatableFull"

                # locate next loop file
                ((++i))
                loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            done
        done
    done
    # check if there was something exported
    rowcount=$(wc -l "$datatableShort" | awk '{print $1}')
    if [ "$rowcount" -lt 2 ];then
        okfail fail "nothing to export"
        rm "$datatableShort"
        return
    fi

    # create a tab separated table for pretty formating
    # convert .csv -> .tsv
    column -s ';' -t "$datatableShort" > "${datatableShort::-3}"tsv
    column -s ';' -t "$datatableFull" > "${datatableFull::-3}"tsv
    okfail ok "exported short and full results (${datatableShort::-3}tsv)"

    # push to measurement data git
    repourl=$(grep "repoupload" global-variables.yml | cut -d ':' -f 2-)
    # check if upload git does not exist yet
    if [ ! -d git-upload/.git ]; then
        # clone the upload git repo
        # default to trust server fingerprint authenticity (usually insecure)
        GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new' git clone "${repourl// /}" git-upload
    fi

    echo " pushing experiment measurement data to git repo $repourl"
    cd git-upload || error ${LINENO} "${FUNCNAME[0]} cd into gitrepo failed"
    {
    # a pull is not really required, but for small sizes it doesn't hurt
    git pull
    cp -r ../"$EXPORTPATH" results/
    git add . 
    git commit -a -m "script upload"
    git push 
    } &> /dev/null || error ${LINENO} "${FUNCNAME[0]} git upload failed"
    okfail ok " upload success" 
}

# find out and set a protocols adversary model
setAdvModel() {
    protocol="$1"
    if [[ " ${maldishonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=maldishonest
    elif [[ " ${covertdishonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=covertdishonest
    elif [[ " ${semidishonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=semidishonest
    elif [[ " ${malhonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=malhonest
    elif [[ " ${semihonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=semihonest
    fi
}
