# Benchmark MP-SPDZ programs in pos testing environments

sevarebench is a framework for running [MP-SPDZ](https://github.com/data61/MP-SPDZ#protocols) SMC protocols in a [pos](https://dl.acm.org/doi/10.1145/3485983.3494841) -enabled testbed environment.

## How to

### To enable git-upload of the measurement data
To use this functionality, a repository to store the measurement results is required. How it would work with [github.com](https://github.com/new)

Change global-variables.yml in line "repoupload: git@github.com:reponame/sevaremeasurements.git" to your repository name.

Then you need a ssh keypair. The key needs to be installed on the pos management server. Typically you can check by running the command

```
less ~/.ssh/id_rsa.pub
```

If this displays your ssh public key (ssh-... ... user@host), you could use it in your git repo settings or create a new key-lock pair with 
```
ssh-keygen
```

Use the public key to create a new deploy key for your repository. Add a new Deploy key under "Deploy keys" in the repository settings. Activate "Allow write access".
[docs.github.com Deploy Keys](https://docs.github.com/en/developers/overview/managing-deploy-keys#deploy-keys)


### Start experiment measurement

1. Clone this repo on the pos management node into directory `sevarebench` and enter it

```
ssh -p 10022 <username>@springfield.net.in.tum.de
git clone https://gitlab.lrz.de/tumi8-theses/smc/ba-obrman/code.git sevarebench
cd sevarebench
```

2. Reserve two or more nodes with pos to use with sevarebench

```
pos calendar create -s "now" -d 40 todd rod ned
```

3. Make `servarebench.sh` executable and test usage printing

```
chmod 740 sevarebench.sh
./sevarebench.sh
```

This should print some usage information if successful

4. Execute the testrun config to test functionality

```
./sevarebench.sh --config configs/testrun.conf todd,rod,ned &> sevarelog01 &
disown %-  # your shell might disown by default
```

This syntax backgrounds the experiment run and detaches the process from the shell so that it continues even after disconnect. Track the output of sevarebench in the file `sevarelog01` at any time with (90 is number of previous lines to print):

```
tail -Fn 90 sevarelog01
```


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

### No protocol compile option support

When compiling the SMC protocols, it is possible to specify compile options such as "-DINSECURE" in the file CONFIG.mine of MP-SPDZ. A custom flag to support this feature is desired.

### No program compile option support

When compiling high level SMC programs, currently a default value with maxmimum support for most protocols is used, such as "-B 64". In some cases, specifiying a custom value can improve performance. Support for custom parameters is desired.

### Only exporting measurements from first node

The measurement result data set is exported only from the first node of the node argument value when starting sevarebench.