### Deployment on testnet

#### Code Saftey deployment
> Due to the transparency of the codes on the testnet, we use two ways to keep code safe.

Step 1. Deploy empty codes to cache the FlowScan before your first deployment only once.
   * `python ./scripts/deployment/testnet/GenTmpCodes.py` to generate all empty&mixture codes and configs.
   * `python ./scripts/deployment/testnet/DeployEmptyOnTestnet.py` to deploy empty contracts.
   > The script will automatically open the browser to access flowscan for effective caching.
   * `python ./scripts/deployment/testnet/UndeployTestnet.py` to clear your deployment.

Step 2. After GenTmpCodes.py, all mixture codes will be generated locally, including contracts, transcations, and scripts.
   * `python ./scripts/deployment/testnet/DeployUnreadableOnTestnet.py` to deploy all the contracts and initializations.

After using the test environment, please undeploy the codes in time.
   * `python ./scripts/deployment/testnet/UndeployTestnet.py`

#### Deployment configs
> All the configs is included in `flow.json`

1. All the pool's params: `flow.json` ["pools"]
2. All the interest model's params: pls config `flow.json` ["interest-rate-models"]
3. Do not configure the pool&interestModel deployments in `flow.json` 
   (because flow cannot be deployed with the same name)
   you only need to configure the deployer of the pool, and then configure the [pools] for automatically deployment.

* TODO:  Add script to deploy pool singly.
