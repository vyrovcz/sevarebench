#! /usr/bin/python3

import os.path
import numpy as np
np.set_printoptions(threshold=np.inf)
np.set_printoptions(linewidth=np.inf)

print("\n----Python unconcealed computation start----\n")

# count players
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0-v"):
    player += 1

if player == 0:
    exit()

# count inputs
f = open("Player-Data/Input-P0-0-v", 'r')
size = len(f.readline().split())

inputs = np.zeros( (player, size), dtype=int)
# fill player inputs
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0-v"):
    f = open("Player-Data/Input-P" + str(player) +"-0-v", 'r')
    inputs[player] = np.array(f.readline().split())
    player += 1

# find matches, 0 for no match, 1 if match
result = np.ones(size, dtype=int)
for i in range(size):
    for j in range(1,player):
        if inputs[0][i] in inputs[j]:
            result[i] = 1
            break
        result[i] = 0

print([x for x in result])

print("\n----Python unconcealed computation stop----\n")
