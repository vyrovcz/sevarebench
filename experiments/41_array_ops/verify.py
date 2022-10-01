#! /usr/bin/python3
import numpy as np
import sys

precision = 0.1

# move values to array, expected as arguments
result_is = np.array([float(i) for i in sys.argv[1].split(",")])
result_expected= np.array([float(i) for i in sys.argv[2].split()])

print(1) if np.allclose(result_is,result_expected,0,precision) else print(0)
#could also do symmetric difference to find the differing values