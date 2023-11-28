# Benchmark MP-SPDZ Secure Multiparty Computation programs in pos orchestration  environments

sevarebench is a framework for running [MP-SPDZ](https://github.com/data61/MP-SPDZ#protocols) SMC protocols in a [pos](https://dl.acm.org/doi/10.1145/3485983.3494841) -enabled testbed environment.

## How to

### To enable git-upload of the measurement data
To use this functionality, a repository to store the measurement results is required. How it would work with [github.com](https://github.com/new):

Change global-variables.yml in line "repoupload: git@github.com:reponame/sevaremeasurements.git" to your repository name.

Then you need a ssh key on your pos management server. Typically you can check for existing keys by running the command

```
less -e ~/.ssh/id_rsa.pub
```

If this displays your ssh public key (ssh-... ... user@host), you could use it in your git repo settings or create a new key-lock pair with 
```
ssh-keygen
```

Use the public key to create a new deploy key for your repository. Add a new Deploy key under "Deploy keys" in the repository settings. Activate "Allow write access". Or hand your public key to your repository admin.
[docs.github.com Deploy Keys](https://docs.github.com/en/developers/overview/managing-deploy-keys#deploy-keys)


### Start experiment measurement

1. Clone this repo on the pos management node into directory `sevarebench` and enter it

```
ssh -p 10022 <username>@<pos-management-server-hostname>
git clone https://github.com/vyrovcz/sevarebench.git
cd sevarebench
```

2. Reserve two or more nodes with pos to use with sevarebench

```
pos calendar create -s "now" -d 40 node1 node2 node3
```

3. Make `servarebench.sh` executable and test usage printing

```
chmod 740 sevarebench.sh
./sevarebench.sh
```

This should print some usage information if successful

4. Execute the testrun config to test functionality

```
./sevarebench.sh --config configs/testruns/testrunBasic.conf node1,node2,node3 &> sevarelog01 &
disown %-  # your shell might disown by default
```

This syntax backgrounds the experiment run and detaches the process from the shell so that it continues even after disconnect. Track the output of sevarebench in the logfile `sevarelog01` at any time with:

```
tail -F sevarelog01
```

Stuck runs should be closed with sigterm code 15 to the process owning all the testnodes processes. For example with 
```
htop -u $(whoami)
```
and F9. This activates the trap that launches the verification and exporting of the results that have been collected so far, which could take some time. Track the process in the logfile


### Add new experiment

Example adding with experiment 36_matrix_mul_float



### Add new testbed hosts

#### Switch topology

In `global-variables.yml` simply add the following lines with the respective names for `testbed`, `node`, and `interfacename`

```
# testbedAlpha NIC configuration
node1NIC0: &NICtestbedA <interfacename>
node2NIC0: *NICtestbedA
...
node3NIC0: *NICtestbedA
```

#### Direct connection topology

Design and define node connection model. Recommended and intuitive is the circularly sorted approach like in the following example. Already implemented directly connected nodes are also defined in a circularly sorted fashion.


## Known limitations

### No program compile option support

When compiling high level SMC programs, currently a default value with maxmimum support for most protocols is used, such as "-B 64". In some cases, specifiying a custom value can improve performance. Support for custom parameters is desired.

### Only exporting measurements from first node

The measurement result data set is exported only from the first node of the node argument value when starting sevarebench.