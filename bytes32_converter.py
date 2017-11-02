#!/usr/bin/env python2.7
import sys
import random
import json

def generateRandomSalt(length = 16):
	chars=[]
	for i in range(16):
		chars.append(random.choice(ALPHABET))
	return "".join(chars)

ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

bytes32Array = []
#argInput = sys.argv[1]

print "Generated secret: "
print generateRandomSalt()
argInput = raw_input("Please enter the hash: ")

if (argInput[0:2] == "0x"):
	argInput = argInput[2:]

for i in range(0, len(argInput), 2):
	bytes32Array.append("0x" + str(argInput[i:i+2]))

print argInput
print json.dumps(bytes32Array)
