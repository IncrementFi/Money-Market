import os
import sys
import json
import shutil
import re
import ConfigTestnet


PoolDeployerNameToAddr = ConfigTestnet.ExtractPoolDeployers('testnet')
ComptrollerDeployer = ConfigTestnet.ExtractComptrollerDeployer()
InterestDeployerNameToAddr = ConfigTestnet.ExtractInterestDeployers('testnet')

# Add markets
for poolDeployer in PoolDeployerNameToAddr:
    poolAddr = PoolDeployerNameToAddr[poolDeployer]
    poolConfig = ConfigTestnet.ExtractPoolConfig(poolDeployer, 'testnet')
    print('===============>', 'config market', poolDeployer)
    cmd = 'flow transactions send {0}/transactions/Comptroller/config_market.cdc '.format(ConfigTestnet.UnreadablePath) + \
          '--arg Address:{0} '.format(poolAddr) + \
          '--arg UFix64:{0} '.format(poolConfig['liquidationPenalty']) + \
          '--arg UFix64:{0} '.format(poolConfig['collateralFactor']) + \
          '--arg UFix64:{0} '.format(poolConfig['borrowCap']) + \
          '--arg UFix64:{0} '.format(poolConfig['supplyCap']) + \
          '--arg Bool:{0} '.format(poolConfig['isOpen']) + \
          '--arg Bool:{0} '.format(poolConfig['isMining']) + \
          '--signer {0} '.format(ComptrollerDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)

# Init interest rate model
for interestDeployer in InterestDeployerNameToAddr:
    print('\n===============>', 'upadte interest model', interestDeployer)
    interestConfig = ConfigTestnet.ExtractInterestConfig(interestDeployer, 'testnet')
    cmd = 'flow transactions send '+ ConfigTestnet.UnreadablePath +'/transactions/InterestRateModel/autogen/update_model_params.cdc.{0}.tmp '.format(interestDeployer) + \
          '--arg UInt256:"{0}" '.format(interestConfig['blocksPerYear']) + \
          '--arg UInt256:"{0}" '.format(interestConfig['scaledZeroUtilInterestRatePerYear']) + \
          '--arg UInt256:"{0}" '.format(interestConfig['scaledCriticalUtilInterestRatePerYear']) + \
          '--arg UInt256:"{0}" '.format(interestConfig['scaledFullUtilInterestRatePerYear']) + \
          '--arg UInt256:"{0}" '.format(interestConfig['scaledCriticalUtilRate']) + \
          '--signer {0} '.format(interestDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)