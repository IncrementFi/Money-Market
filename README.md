# Money Market

### Dev environment setup (Once):
* [Install flow-cli tool with emulator environment](https://docs.onflow.org/flow-cli/install/)
* Install json parsing tool `jq` by `brew install jq`
* Run `yarn` or `npm install`
* Start emulator by `flow emulator -v`, (use `--persist` flag if want to reuse emulator environment)
* Check and run `./commands/gen-env-keys.sh` several times, basically it performs:
  - Generate {privateKey, publicKey} pair by `flow keys generate --sig-algo=ECDSA_secp256k1`
  - Create emulator deployer accounts (see `flow.json`) by `flow accounts create --key "generated-publicKey" --sig-algo "ECDSA_secp256k1" --signer "emulator-account"`
* Replace emulator deployers' `privateKey` fields in `flow.json` file correspondingly, or simply keep the given json file unchanged, whose {privateKey, publicKey} are listed below:
```
flow keys generate --sig-algo=ECDSA_secp256k1

🔴️ Store private key safely and don't share with anyone! 
Private Key 	 3e173ab34b4629ee8e16ee95a6aacb5f088fc95e53ba28ef0f528bf8bcce51ec 
Public Key 	 95efe052cc2e1be2162cb4c273ab86a4602369536fac60e835c63ee5fc856ad7f6f4d17eb505af54482caac0addeb9b2b24e7b44eb79cb02e19be106c1cbfd4f 
```


### Deploy multipools on emulator:
1. Run `flow emulator -v` to start emulator
2. Run `./tools/deployment/emulator/multipool-deploy.sh` to deploy accounts and contracts.
3. Run `./tools/deployment/emulator/multipool-test.sh` for testing.
   or Run `python ./tools/testbot/UserRandomEmulator.py 12` for multiple users simulation.
###### pool setting:
./tools/emulator/multipool_setting.py can be modified to support various pools.
###### clear tmp codes:
python ./tools/emulator/gen_tmp_codes.py 1

### Deploy on testnet:
1. Run `python ./tools/deployment/testnet/GenTmpCodes.py` to generate all empty&mixture codes and configs.
2. Run `python ./tools/deployment/testnet/DeployEmptyOnTestnet.py` to deploy empty contracts.
3. Run `python ./tools/deployment/testnet/UndeployTestnet.py` to clear your deployment.
4. Run `python ./tools/deployment/testnet/DeployUnreadableOnTestnet.py` to deploy all the contracts and initializations.



### Unittest with [flow-js-testing](https://github.com/onflow/flow-js-testing):
* Docs: https://docs.onflow.org/flow-js-testing/
* Testsuite setup: Check examples under ./tests/setup/setup_\<your_testsuite\>.js
* Testsuite development: Check examples under ./tests/test/\<your_testsuite\>.test.js
* Use different emulator port for different testsuites to run test simultaneously.
* **Note**: To get unittest framework work properly, do NOT break transaction & script arguments into multiple lines, until [this issue](https://github.com/onflow/flow-cadut/issues/15) gets fixed.



### Run tests:
* `npm test`


### Testnet Faucet:
* https://testnet-faucet.onflow.org/


### Testnet Deployment Address:
| Name | Address |
| -------- | ------- |
| LendingConfig | [0xa914b5106275c637](https://testnet.flowscan.org/account/0xa914b5106275c637) |
| LendingInterfaces | [0xa914b5106275c637](https://testnet.flowscan.org/account/0xa914b5106275c637) |
| SimpleOracle | [0x00bb0ede202e2a11](https://testnet.flowscan.org/account/0x00bb0ede202e2a11) |
| OracleUpdater | [0xed8eaa1512ba24aa](https://testnet.flowscan.org/account/0xed8eaa1512ba24aa) |
