#!/bin/bash

python ./scripts/emulator/gen_tmp_codes.py

python ./scripts/emulator/deploy_multipools.py

python ./scripts/emulator/gen_error_codes.py

