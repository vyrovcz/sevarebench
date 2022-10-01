#! /usr/bin/python3
import numpy as np
import sys
import os.path
import re

precision = 0.01

def load_results(path):
    f = open(path,'r')
    for line in f:
        if line[0] == '[' and line[len(line)-2] == ']':
            # convert string to np float array
            return np.array([float(x) for x in re.split('  |, | ',line[1:-2])])
    print("Value not found error " + path)
    exit()

# load inputs
r_is = load_results(sys.argv[1])
r_expected = load_results(sys.argv[2])

# find symmetric set difference
print(1) if np.allclose(r_is,r_expected,0,precision) \
    else print("Verify error: " + str(r_is[:17]) + "(...) != " + str(r_expected[:17]) + "(...)")