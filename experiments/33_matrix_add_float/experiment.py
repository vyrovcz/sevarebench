#! /usr/bin/python3

import os.path
import numpy as np
np.set_printoptions(threshold=np.inf)
np.set_printoptions(linewidth=np.inf)

print("\n----Python unconcealed computation start----\n")

# count players
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0"):
    player += 1

if player == 0:
    exit()

# count inputs
f = open("Player-Data/Input-P0-0", 'r')
size = len(f.readline().split())

inputs = np.zeros( (player, size) )
# fill player inputs
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0"):
    f = open("Player-Data/Input-P" + str(player) +"-0", 'r')
    inputs[player] = np.array(f.readline().split())
    player += 1

# sum player inputs
result = np.sum(inputs,axis=0)

# need to create new standard python array to print
# because of this: https://stackoverflow.com/q/23870301 (or sth similar...)
print([x for x in np.around(result,decimals=8)])

print("\n----Python unconcealed computation stop----\n")