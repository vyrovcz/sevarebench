#! /usr/bin/python3
import numpy as np
import sys
import os.path
import re

def load_results(path):
    f = open(path,'r')
    for line in f:
        if line[0] == '[' and line[len(line)-2] == ']':
            # convert string to np array
            return np.array([int(x) for x in re.split('  |, | ',line[1:-2])])
    print("Value not found error " + path)
    exit()

# load inputs
r_is = load_results(sys.argv[1])
r_expected = load_results(sys.argv[2])

# find symmetric set difference
diff = np.setdiff1d(r_is, r_expected)
print(1) if r_is[0] == r_expected[0] else print(str(r_is[0]) + " != " + str(r_expected[0]))