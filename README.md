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


### Deploy to emulator:



### Deploy to testnet:



### Unittest with [flow-js-testing](https://github.com/onflow/flow-js-testing):
* Docs: https://docs.onflow.org/flow-js-testing/
* Testsuite setup: Check examples under ./tests/setup/setup_\<your_testsuite\>.js
* Testsuite development: Check examples under ./tests/test/\<your_testsuite\>.test.js
* Use different emulator port for different testsuites to run test simultaneously.
* **Note**: To get unittest framework work properly, do NOT break transaction & script arguments into multiple lines, until [this issue](https://github.com/onflow/flow-cadut/issues/15) gets fixed.



### Run tests:
* `npm test`


### Testnet Deployment Address:
| Name | Address |
| -------- | ------- |
| SimpleOracle | [0x3e1c9476cfe21394](https://testnet.flowscan.org/account/0x3e1c9476cfe21394) |