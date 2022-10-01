#! /usr/bin/python3

import sys
import os.path
import numpy as np
np.set_printoptions(threshold=np.inf)
np.set_printoptions(linewidth=np.inf)

print("\n----Python unconcealed computation start----\n")

etype = int(sys.argv[1])
datatype = int
if etype > 3:
    datatype = float

# count players
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0"):
    player += 1

if player == 0:
    exit()

# count inputs
f = open("Player-Data/Input-P0-0", 'r')
size = len(f.readline().split())

inputs = np.zeros( (player, size), dtype=datatype)
# fill player inputs
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0"):
    f = open("Player-Data/Input-P" + str(player) +"-0", 'r')
    inputs[player] = np.array(f.readline().split())
    player += 1

if etype in [1, 5]:
    result = np.sum(inputs,axis=0)
if etype in [2, 6]:
    result = inputs[0]
    for i in range(1, len(inputs)):
        result = np.subtract(result, inputs[i])
if etype in [3, 7]:
    result = inputs[0]
    for i in range(1, len(inputs)):
        result = np.multiply(result, inputs[i])
if etype in [4, 8]:
    result = inputs[0]
    for i in range(1, len(inputs)):
        result = np.divide(result, inputs[i])

print([x for x in result])

print("\n----Python unconcealed computation stop----\n")