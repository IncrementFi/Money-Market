import os
import sys
import json
import shutil
import re
import ConfigTestnet


undeployContractNameSingly = None
if len(sys.argv) > 1:
    undeployContractNameSingly = sys.argv[1]


# Extracts all pool&interestRate Deployers
PoolDeployerNameToAddr = ConfigTestnet.ExtractPoolDeployers()
InterestDeployerNameToAddr = ConfigTestnet.ExtractInterestDeployers()

# Pool contract name
poolContractName = ConfigTestnet.Encrypt('LendingPool')
interestContractName = ConfigTestnet.Encrypt('TwoSegmentsInterestRateModel')

with open('./scripts/deployment/testnet/flow.empty.json', 'r') as f:
    flow_empty_dict = json.load(f)

# Remove contracts in flow.json
for deployer in flow_empty_dict['deployments']['testnet']:
    for contractName in flow_empty_dict['deployments']['testnet'][deployer]:
        if undeployContractNameSingly != None and undeployContractNameSingly != contractName: continue

        contractAddr = flow_empty_dict['accounts'][deployer]['address'][2:]
        print('\n=======>', 'undeploy ', contractName)
        os.system(
            'flow accounts remove-contract {0} --signer {1} --network testnet -f ./scripts/deployment/testnet/flow.empty.json'.format(
            contractName, deployer
        )
    )

if undeployContractNameSingly == None:
    # Remove pools
    for poolDeployer in PoolDeployerNameToAddr:
        print('\n=======>', 'undeploy ', poolDeployer)
        os.system(
            'flow accounts remove-contract {0} --signer {1} --network testnet -f ./scripts/deployment/testnet/flow.empty.json'.format(
            poolContractName, poolDeployer
            )
        )
    # Remove interest mode
    for interestDeployer in InterestDeployerNameToAddr:
        print('\n=======>', 'undeploy ', interestDeployer)
        os.system(
            'flow accounts remove-contract {0} --signer {1} --network testnet -f ./scripts/deployment/testnet/flow.empty.json'.format(
            interestContractName, interestDeployer
            )
        )
