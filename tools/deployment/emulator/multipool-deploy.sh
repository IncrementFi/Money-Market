#!/bin/bash

python ./tools/emulator/gen_tmp_codes.py

python ./tools/emulator/deploy_multipools.py

python ./tools/emulator/gen_error_codes.py

