# -*- coding: utf-8 -*-

import os
import sys
import json


ErrorIdentifierStart = False
ErrorIndex = 0
ErrorJson = {}
with open('./cadence/contracts/Config.cdc', 'r') as f:
    for line in f:
        line = line.strip()
        if line.startswith('pub enum Error: UInt8'): ErrorIdentifierStart = True
        if ErrorIdentifierStart and line.startswith('}'): ErrorIdentifierStart = False
        if ErrorIdentifierStart == False: continue

        if line.startswith('pub case '):
            msg = line[9:]
            ErrorJson[ErrorIndex] = {}
            ErrorJson[ErrorIndex]['eng'] = msg
            ErrorJson[ErrorIndex]['chn'] = msg+'的喵'
            ErrorIndex = ErrorIndex + 1 


with open("./increment.errorcode.json", 'w') as fw:
    json_str = json.dumps(ErrorJson, indent=2, ensure_ascii=False)
    fw.write(json_str)
