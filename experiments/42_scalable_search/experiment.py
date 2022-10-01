#! /usr/bin/python3

print("\n----Python unconcealed computation start----\n")

f = open("Player-Data/Input-P0-0-v", 'r')
numstr = f.readline()
haystack = [int(i) for i in numstr.split()]


f = open("Player-Data/Input-P1-0-v", 'r')
numstr = f.readline()
needle= int(numstr.split()[0])

print("[1]" if needle in haystack else "[0]")
print("haystack and needle:")
print(haystack)
print(needle)
print("\n----Python unconcealed computation stop----\n")
