import os
import sys
import json
import shutil
import re
import ConfigTestnet

# Deploy empty contracts without pools
os.system('flow project deploy -f ./tools/deployment/testnet/flow.empty.json --update --network testnet')
# Extracts all pool Deployers
PoolDeployerNameToAddr = ConfigTestnet.ExtractPoolDeployers('testnet')
InterestDeployerNameToAddr = ConfigTestnet.ExtractInterestDeployers('testnet')
# Pool contract name
poolContractName = ConfigTestnet.GetLendingPoolContractName()
interestModelContractName = ConfigTestnet.GetInterestContractName()
# Deploy empty pool contracts
for poolDeployer in PoolDeployerNameToAddr:
    print('\n=======> remove ', poolDeployer)
    os.system(
        'flow accounts remove-contract {0} --signer {1} --network testnet -f ./tools/deployment/testnet/flow.empty.json'.format(
            poolContractName, poolDeployer
        )
    )
    print('=======> deploy ', poolDeployer)
    os.system(
        'flow accounts add-contract {0} ./tools/deployment/testnet/cadence_empty/contracts/{1}.cdc --signer {2} --network testnet -f ./tools/deployment/testnet/flow.empty.json'.format(
            poolContractName, poolContractName, poolDeployer
        )
    )

# Deploy empty interest contracts
for interestDeployer in InterestDeployerNameToAddr:
    print('\n=======> remove ', interestDeployer)
    os.system(
        'flow accounts remove-contract {0} --signer {1} --network testnet -f ./tools/deployment/testnet/flow.empty.json'.format(
            interestModelContractName, interestDeployer
        )
    )
    print('=======> deploy ', interestDeployer)
    os.system(
        'flow accounts add-contract {0} ./tools/deployment/testnet/cadence_empty/contracts/{1}.cdc --signer {2} --network testnet -f ./tools/deployment/testnet/flow.empty.json'.format(
            interestModelContractName, interestModelContractName, interestDeployer
        )
    )


# Cache the FlowScan
with open('./tools/deployment/testnet/flow.empty.json', 'r') as f:
    flow_empty_dict = json.load(f)

for deployer in flow_empty_dict['deployments']['testnet']:
    for contractName in flow_empty_dict['deployments']['testnet'][deployer]:
        contractAddr = flow_empty_dict['accounts'][deployer]['address'][2:]
        os.system(
            'open \'https://testnet.flowscan.org/contract/A.{0}.{1}\''.format(
                contractAddr, contractName
            )
        )
for poolDeployer in PoolDeployerNameToAddr:
    os.system(
        'open \'https://testnet.flowscan.org/contract/A.{0}.{1}\''.format(
            PoolDeployerNameToAddr[poolDeployer][2:], poolContractName
        )
    )
for interestDeployer in InterestDeployerNameToAddr:
    os.system(
        'open \'https://testnet.flowscan.org/contract/A.{0}.{1}\''.format(
            InterestDeployerNameToAddr[interestDeployer][2:], interestModelContractName
        )
    )
