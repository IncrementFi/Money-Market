# -*- coding: utf-8 -*-

import os
import sys
import json
import re

ErrorIdentifierStart = False
ErrorIndex = 0
ErrorJson = {}
with open('./cadence/contracts/LendingError.cdc', 'r') as f:
    for line in f:
        line = line.strip()
        if line.startswith('pub enum '): ErrorIdentifierStart = True
        if ErrorIdentifierStart and line.startswith('}'): ErrorIdentifierStart = False
        if ErrorIdentifierStart == False: continue

        if line.find('pub case ')>=0:
            msgReg = re.compile(r'pub case (.+?)\b')
            res = msgReg.search(line)
            
            msg = res[1]
            ErrorJson[ErrorIndex] = {}
            ErrorJson[ErrorIndex]['eng'] = msg
            ErrorJson[ErrorIndex]['chn'] = msg
            ErrorIndex = ErrorIndex + 1 


with open("./increment.errorcode.json", 'w') as fw:
    json_str = json.dumps(ErrorJson, indent=2, ensure_ascii=False)
    fw.write(json_str)
