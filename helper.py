#!/usr/bin/env python3
'''''''''''''''''''''''''''''
COPYRIGHT FETCH DEVELOPMENT,
2021

'''''''''''''''''''''''''''''
import json
import sys

RED = "\033[31m"
GRN = "\033[32m"
ORG = "\033[33m"
BLD = "\033[1m"
RES = "\033[0m"

def my_except_hook(exctype, value, traceback):
	print(f'{RED + BLD}ERROR:{RES} {value}')
	exit(-1)
sys.excepthook = my_except_hook

argv = sys.argv
if len(argv) < 2:
	raise ValueError("no path to file provided")
path = argv[1]
with open(path, 'r') as f:
	data = json.load(f)
print(f"{ORG + BLD}WARNING:{RES} this will rewrite known disk data for all tracks")
data['reliable'] = True
data['title'] = input("Enter disk name > ")
album = input("Enter album title (Leave blank if should set to null) > ")
artist = input("Enter artist name (Leave blank if should set to null) > ")
track = input("Enter track title (Leave blank if should set to null) > ")
if album == "":
	album = None
if artist == "":
	artist = None
if track == "":
	track = None
for i in range(0, len(data['tracks'])):
	data['tracks'][i]['album'] = album
	data['tracks'][i]['artist'] = artist
	data['tracks'][i]['title'] = track
with open(path, 'w') as f:
	json.dump(data, f)
print(f"{GRN + BLD}SUCCESSFULLY{RES} written")
