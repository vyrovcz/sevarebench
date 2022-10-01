#! /usr/bin/python3

import os.path
import numpy as np

print("\n----Python unconcealed computation start----\n")

# count players
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0"):
    player += 1

# hardcode 2 player for this experiment
player = player if player < 2 else 2

if player == 0:
    exit()

# count inputs
f = open("Player-Data/Input-P0-0", 'r')
size = len(f.readline().split())

inputs = np.zeros( (player, size), dtype=int)
# fill player inputs
player = 0
while os.path.isfile("Player-Data/Input-P" + str(player) +"-0") and player < 2 :
    f = open("Player-Data/Input-P" + str(player) +"-0", 'r')
    inputs[player] = np.array(f.readline().split())
    player += 1

# find matches, 0 for no match, the number if match
result = np.ones(size, dtype=int)
for i in range(size):
    for j in range(1,player):
        if inputs[0][i] in inputs[j]:
            result[i] = inputs[0][i]
            break
        result[i] = 0

print("SMC-Result:",[i for i in result])

print("\n----Python unconcealed computation stop----\n")
