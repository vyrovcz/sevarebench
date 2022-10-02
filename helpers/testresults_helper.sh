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
# Export general experiment data from the pos_upload-ed logs into one table
############
exportShortExperimentResults() {

    # set up location
    datatable="$EXPORTPATH/data/E${EXPERIMENT::2}_short_results.csv"
    mkdir -p "$datatable"
    rm -rf "$datatable"

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
    echo -e "nodes;program;c.domain;adv.model;protocol;${dyncolumns}runtime(s);maxPhyRAM(MiB)" >> "$datatable"
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
                # extract measurement
                runtime=$(grep "Time =" "$runtimeinfo" | awk '{print $3}')
                maxRAMused=$(grep "maxresident)k" "$runtimeinfo" | awk '{print $6}' | cut -d 'm' -f 1)
                [ -n "$maxRAMused" ] && maxRAMused="$((maxRAMused/1024))"

                ((++i))
                # put all collected info into one row
                echo -e "${usednodes// /,};$EXPERIMENT;$cdomain;$advModel;$protocol;$compilevalues;$loopvalues$runtime;$maxRAMused" >> "$datatable"
                loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            done
        done
    done
    # check if there was something exported
    rowcount=$(wc -l "$datatable" | awk '{print $1}')
    if [ "$rowcount" -lt 2 ];then
        okfail fail "nothing to export"
        rm "$datatable"
        return
    fi

    # create a tab separated table for pretty formating
    # convert .csv -> .tsv
    column -s ';' -t "$datatable" > "${datatable::-3}"tsv
    okfail ok "exported to ${datatable::-3}{csv, tsc}"
}

############
### Export all experiment data from the pos_upload-ed logs into one table
### and push to git specified in global var
############
exportFullExperimentResults() {

    # set up location
    datatable="$EXPORTPATH/data/E${EXPERIMENT::2}_full_results.csv"

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
    echo -e "nodes;program;c.domain;adv.model;protocol;comp.intbits;comp.inttriples;comp.vmrounds;${dyncolumns}runtime(s);maxPhyRAM(MiB);P0commRounds;P0dataSent(MB);ALLdataSent(MB)" >> "$datatable"
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
                
                compileinfo=$(find "$resultpath" -name "measurementlog${cdomain}_run*$i" -print -quit)
                runtimeinfo=$(find "$resultpath" -name "testresults$cdomain${protocol}_run*$i" -print -quit)
                if [ ! -f "$runtimeinfo" ] || [ ! -f "$compileinfo" ]; then
                    styleOrange "    Skip - File not found error: runtimeinfo or compileinfo"
                    continue 2
                fi
                # extract compile information (this is repeated many times, potential to optimize)
                intbits=$(grep " integer bits" "$compileinfo" | awk '{print $1}')
                inttriples=$(grep " integer triples" "$compileinfo" | awk '{print $1}')
                vmrounds=$(grep " virtual machine rounds" "$compileinfo" | awk '{print $1}')
                compilevalues="${intbits:-NA};${inttriples:-NA};${vmrounds:-NA}"
                # extract measurement
                runtime=$(grep "Time =" "$runtimeinfo" | awk '{print $3}')
                maxRAMused=$(grep "MaxPhysicalMemory" "$runtimeinfo" | cut -d '=' -f 2 | cut -d 'K' -f 1)
                commRounds=$(grep "Data sent =" "$runtimeinfo" | awk '{print $7}')
                dataSent=$(grep "Data sent =" "$runtimeinfo" | awk '{print $4}')
                globaldataSent=$(grep "Global data sent =" "$runtimeinfo" | awk '{print $5}')
                [ -n "$maxRAMused" ] && maxRAMused="$((maxRAMused/1024));"
                measurementvalues="$runtime;$maxRAMused${commRounds:-NA};${dataSent:-NA};${globaldataSent:-NA}"

                ((++i))
                # put all collected info into one row
                echo -e "${usednodes// /,};$EXPERIMENT;$cdomain;$advModel;$protocol;$compilevalues;$loopvalues$measurementvalues" >> "$datatable"
                loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            done
        done
    done
    # check if there was something exported
    rowcount=$(wc -l "$datatable" | awk '{print $1}')
    if [ "$rowcount" -lt 2 ];then
        okfail fail "nothing to export"
        rm "$datatable"
        return
    fi

    # create a tab separated table for pretty formating
    # convert .csv -> .tsv
    column -s ';' -t "$datatable" > "${datatable::-3}"tsv
    okfail ok "exported to ${datatable::-3}{csv, tsc}"

    # push to measurement data git
    # check if upload git does not exist yet
    if [ ! -d git-upload/.git ]; then
        # clone the upload git repo
        repourl=$(grep "repoupload" global-variables.yml | cut -d ':' -f 2-)
        git clone "${repourl// /}" git-upload
    fi

    echo " pushing experiment measurement data to git repo"
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
