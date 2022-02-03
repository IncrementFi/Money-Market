import os
import sys
import json
import shutil
import re
import ConfigTestnet

PoolDeployerNameToAddr = ConfigTestnet.ExtractPoolDeployers('testnet')
InterestDeployerNameToAddr = ConfigTestnet.ExtractInterestDeployers('testnet')

OracleDeployer = ConfigTestnet.ExtractOracleDeployer()
OracleUpdater = ConfigTestnet.ExtractOracleUpdater()
ComptrollerDeployer = ConfigTestnet.ExtractComptrollerDeployer()

ContractNameToAddress = ConfigTestnet.ExtractContractNameToAddress('./tools/deployment/testnet/flow.unreadable.json')
DeployerToAddress = ConfigTestnet.ExtractDeployerToAddress('./tools/deployment/testnet/flow.unreadable.json')

PoolContractName = ConfigTestnet.GetLendingPoolContractName()
InterestModelContractName = ConfigTestnet.GetInterestContractName()
ComptrollerContractName = ConfigTestnet.GetComptrollerContractName()


# Deploy contracts without pools & interest models
os.system('flow project deploy -f ./tools/deployment/testnet/flow.unreadable.json --update --network testnet')

# Deploy Interest Model
for interestDeployer in InterestDeployerNameToAddr:
    print('===============>', 'deploy ', interestDeployer)
    #-f ./tools/deployment/testnet/flow.unreadable.json
    os.system('flow accounts remove-contract {0} --signer {1} --network testnet'.format(
        InterestModelContractName, interestDeployer))
    os.system('flow accounts add-contract {0} ./tools/deployment/testnet/cadence_unreadable/contracts/autogen/{1}.cdc.addr --signer {2} --network testnet'.format(
        InterestModelContractName, InterestModelContractName, interestDeployer))


# Init interest rate model
for interestDeployer in InterestDeployerNameToAddr:
    print('\n===============>', 'init interest model', interestDeployer)
    interestConfig = ConfigTestnet.ExtractInterestConfig(interestDeployer, 'testnet')
    cmd = 'flow transactions send '+ ConfigTestnet.UnreadablePath +'/transactions/InterestRateModel/autogen/create_interest_rate_model.cdc.{0}.tmp '.format(interestDeployer) + \
          '--arg String:"{0}" '.format(interestConfig['modelName']) + \
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


# Prepare underlying vault for pools
for poolDeployer in PoolDeployerNameToAddr:
    print('\n===============>', 'prepare underlying vault for', poolDeployer)
    cmd = 'flow transactions send '+ ConfigTestnet.UnreadablePath +'/transactions/Pool/autogen/prepare_template_for_pool.cdc.{0}.tmp '.format(poolDeployer) + \
          '--signer {0} '.format(poolDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)

# Deploy LendingPools
for poolDeployer in PoolDeployerNameToAddr:
    print('===============>', 'deploy pool', poolDeployer)
    #-f ./tools/deployment/testnet/flow.unreadable.json
    os.system('flow accounts remove-contract {0} --signer {1} --network testnet'.format(
        PoolContractName, poolDeployer))
    os.system('flow accounts add-contract {0} {1}/contracts/autogen/{2}.cdc.addr --signer {3} --network testnet'.format(
        PoolContractName, ConfigTestnet.UnreadablePath, PoolContractName, poolDeployer))

# Oracle
for poolDeployer in PoolDeployerNameToAddr:
    poolAddr = PoolDeployerNameToAddr[poolDeployer]
    poolConfig = ConfigTestnet.ExtractPoolConfig(poolDeployer, 'testnet')
    print('===============>', 'add oracle price feed ::: ', poolAddr)
    cmd = 'flow transactions send {0}/transactions/Oracle/add_price_feed.cdc '.format(ConfigTestnet.UnreadablePath) + \
          '--arg Address:{0} '.format(poolAddr) + \
          '--arg Address:{0} '.format(poolConfig['oracleAddr']) + \
          '--signer {0} '.format(OracleDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)

# 1.Deploy and setup oracle resource
"""
print('===============>', 'Oracle setup oracle resource')
cmd = 'flow transactions send '+ ConfigTestnet.UnreadablePath +'/transactions/Oracle/admin_create_oracle_resource.cdc ' + \
        '--signer {0} '.format(OracleDeployer) + \
        '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
        '--network testnet'
print(cmd)
os.system(cmd)
#
# 2.Updater setup account & admin grant role"
print('===============>', 'Oracle updater setup account')
cmd = 'flow transactions send '+ ConfigTestnet.UnreadablePath +'/transactions/Oracle/updater_setup_account.cdc ' + \
        '--signer {0} '.format(OracleUpdater) + \
        '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
        '--network testnet'
print(cmd)
os.system(cmd)
print('===============>', 'Oracle admin grant role')
cmd = 'flow transactions send '+ ConfigTestnet.UnreadablePath +'/transactions/Oracle/admin_grant_update_role.cdc ' + \
        '--signer {0} '.format(OracleDeployer) + \
        '--arg Address:"{0}" '.format(DeployerToAddress[OracleUpdater]) + \
        '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
        '--network testnet'
print(cmd)
os.system(cmd)
#

# 3. Oracle add price feed
for poolDeployer in PoolDeployerNameToAddr:
    poolAddr = PoolDeployerNameToAddr[poolDeployer]
    poolConfig = ConfigTestnet.ExtractPoolConfig(poolDeployer, 'testnet')
    print('===============>', 'add oracle price feed ::: ', poolAddr)
    cmd = 'flow transactions send {0}/transactions/Oracle/admin_add_price_feed.cdc '.format(ConfigTestnet.UnreadablePath) + \
          '--arg Address:{0} '.format(poolAddr) + \
          '--arg Int:{0} '.format(poolConfig['oracleCap']) + \
          '--signer {0} '.format(OracleDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)

    print('===============>', 'update oracle price feed ::: ', poolAddr)
    cmd = 'flow transactions send {0}/transactions/Oracle/updater_upload_feed_data.cdc '.format(ConfigTestnet.UnreadablePath) + \
          '--arg Address:{0} '.format(poolAddr) + \
          '--arg UFix64:{0} '.format(poolConfig['oracleInitialPrice']) + \
          '--signer {0} '.format(OracleUpdater) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    os.system(cmd)
"""

# Init comptroller
print('===============>', 'Init comptroller.')
cmd = 'flow transactions send {0}/transactions/Comptroller/init_comptroller.cdc '.format(ConfigTestnet.UnreadablePath) + \
      '--arg Address:{0} '.format(DeployerToAddress[OracleDeployer]) + \
      '--arg UFix64:{0} '.format(0.5) + \
      '--signer {0} '.format(ComptrollerDeployer) + \
      '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
      '--network testnet'
print(cmd)
os.system(cmd)


# Init pools
for poolDeployer in PoolDeployerNameToAddr:
    poolAddr = PoolDeployerNameToAddr[poolDeployer]
    poolConfig = ConfigTestnet.ExtractPoolConfig(poolDeployer, 'testnet')
    print('===============>', 'Init pool', poolDeployer)
    cmd = 'flow transactions send {0}/transactions/Pool/autogen/init_pool_template.cdc.{1}.tmp '.format(ConfigTestnet.UnreadablePath, poolDeployer) + \
          '--arg Address:{0} --arg Address:{1} --arg UFix64:{2} --arg UFix64:{3} '.format(
              DeployerToAddress[poolConfig['interestRateModelDeployer']],
              DeployerToAddress[ComptrollerDeployer],
              poolConfig['reserveFactor'],
              poolConfig['poolSeizeShare']
          ) + \
          '--signer {0} '.format(poolDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)

# Add markets
for poolDeployer in PoolDeployerNameToAddr:
    poolAddr = PoolDeployerNameToAddr[poolDeployer]
    poolConfig = ConfigTestnet.ExtractPoolConfig(poolDeployer, 'testnet')
    print('===============>', 'add market', poolDeployer)
    cmd = 'flow transactions send {0}/transactions/Comptroller/add_market.cdc '.format(ConfigTestnet.UnreadablePath) + \
          '--arg Address:{0} '.format(poolAddr) + \
          '--arg UFix64:{0} '.format(poolConfig['liquidationPenalty']) + \
          '--arg UFix64:{0} '.format(poolConfig['collateralFactor']) + \
          '--arg UFix64:{0} '.format(poolConfig['borrowCap']) + \
          '--arg Bool:{0} '.format(poolConfig['isOpen']) + \
          '--arg Bool:{0} '.format(poolConfig['isMining']) + \
          '--signer {0} '.format(ComptrollerDeployer) + \
          '-f ./tools/deployment/testnet/flow.unreadable.json ' + \
          '--network testnet'
    print(cmd)
    os.system(cmd)