import json
import os
import multipool_setting as setting

setting.PoolAddrs = []
setting.DictPoolNameToAddr = {}
setting.DictDeployNameToAddr = {}
setting.DictPoolNameToDeployName = {}

# create accounts which will be deployed on flow emulator
for addr in setting.BuildinAddr:
    os.popen('flow accounts create --key 99c7b442680230664baab83c4bc7cdd74fb14fb21cce3cceb962892c06d73ab9988568b8edd08cb6779a810220ad9353f8e713bc0cb8b81e06b68bcb9abb551e --sig-algo "ECDSA_secp256k1"  --signer "emulator-account"').read()

# create multiple pool accounts
for poolName in setting.PoolNames+setting.FakePoolNames:
    res = os.popen('flow accounts create --key 99c7b442680230664baab83c4bc7cdd74fb14fb21cce3cceb962892c06d73ab9988568b8edd08cb6779a810220ad9353f8e713bc0cb8b81e06b68bcb9abb551e --sig-algo "ECDSA_secp256k1"  --signer "emulator-account"').read()
    lines = res.split('\n')
    for line in lines:
        if  line.find('Address') >= 0:
            addr = line.split('\t')[1].lstrip()
            setting.PoolAddrs.append(addr)
            setting.DictPoolNameToAddr[poolName] = addr
            break
print('pool addrs:', setting.PoolAddrs)

# generate flow_multipool.json to support multiple pool deployment on emulator
with open('./flow.json', 'r') as f:
    flow_dict = json.load(f)
    delList = []
    for account in flow_dict['accounts']:
        if account.find('emulator-pool-tmpdeployer') >= 0:
            delList.append(account)
    for delName in delList:
        del flow_dict['accounts'][delName]
    delList = []
    for contract in flow_dict['contracts']:
        if contract.find('LendingPool_') >= 0 or contract.find('Fake') >= 0:
            delList.append(contract)
    for delName in delList:
        del flow_dict['contracts'][delName]
    del flow_dict['deployments']['emulator']['emulator-pool-template']
    
    # add pool accounts in json
    for poolName in setting.PoolNames+setting.FakePoolNames:
        poolAccountName = 'emulator-pool-tmpdeployer-{0}'.format(poolName)
        flow_dict['accounts'][poolAccountName] = {}
        flow_dict['accounts'][poolAccountName]['address'] = setting.DictPoolNameToAddr[poolName]
        flow_dict['accounts'][poolAccountName]['key'] = { "privateKey": "14b15e83fc8b1725e1f949fd9770041ed35631c3035aa569654f9f795674f782", "type": "hex", "index": 0, "signatureAlgorithm": "ECDSA_secp256k1", "hashAlgorithm": "SHA3_256" }
    # add pool deployment in json
    for name in setting.PoolNames+setting.FakePoolNames:
        poolContractName = 'LendingPool_'+name
        flow_dict['contracts'][poolContractName] = "./cadence/contracts/autogen/{0}.cdc".format(poolContractName)
        deployName = "emulator-pool-tmpdeployer-{0}".format(name)
        flow_dict['deployments']['emulator'][deployName] = [poolContractName]
        setting.DictPoolNameToDeployName[name] = deployName
    for poolName in setting.PoolNames+setting.FakePoolNames:
        if poolName == 'FlowToken':
            continue
        if poolName in flow_dict['deployments']['emulator']['emulator-account']:
            continue
        flow_dict['deployments']['emulator']['emulator-account'].append(poolName)
    
    #
    for fakePoolName in setting.FakePoolNames:
        flow_dict['contracts'][fakePoolName] = "./cadence/contracts/autogen/{0}.cdc".format(fakePoolName)
    for deployName in flow_dict['accounts']:
        setting.DictDeployNameToAddr[deployName] = flow_dict['accounts'][deployName]['address']

with open("./flow_multipool.json", 'w') as fw:
    json_str = json.dumps(flow_dict, indent=2)
    fw.write(json_str)

# generate multiple pool env json
with open('./flow_multipool.json', 'r') as f:
    multipool_json = json.load(f)
    multipool_env = multipool_json
    multipool_env['deployments']['emulator'] = {}
    multipool_env['deployments']['emulator']['emulator-account'] = []
    for poolName in setting.PoolNames+setting.FakePoolNames:
        if poolName == 'FlowToken':
            continue
        multipool_env['deployments']['emulator']['emulator-account'].append(poolName)
with open("./flow_multipool_env.json", 'w') as fw:
    json_str = json.dumps(multipool_env, indent=2)
    fw.write(json_str)



# deposit base flow token on account
for deployName in flow_dict['deployments']['emulator']:
    addr = setting.DictDeployNameToAddr[deployName]
    os.system('flow transactions send ./cadence/transactions/Test/emulator_flow_transfer.cdc {0} --signer emulator-account'.format(addr))


# deploy env contracts: tokens
os.system('flow project deploy --update -f flow_multipool_env.json')

print('------------- ', 'init pool\'s token vault')
# call transactions to init token vault.
for poolName in setting.PoolNames+setting.FakePoolNames:
    cmd = 'flow transactions send ./cadence/Transactions/Pool/autogen/prepare_{0}_vault_for_pool.cdc -f flow_multipool.json --signer emulator-pool-tmpdeployer-{1}'.format(poolName, poolName)
    os.system(cmd)

# deploy contracts
print('-------------', 'deploy contracts')
os.system('flow project deploy --update -f flow_multipool.json')



############################
##### setup
# setup intereset rate model
os.system('./scripts/emulator/emulator-setup-InterestRateModel.sh')
# setup oracle
os.system('./scripts/emulator/emulator-setup-Oracle.sh')
for poolName in setting.PoolNames+setting.FakePoolNames:
    poolAddr = setting.DictPoolNameToAddr[poolName]
    print('----- add oracle price feed ::: ', poolName, poolAddr)
    cmd = 'flow transactions send cadence/transactions/Oracle/admin_add_price_feed.cdc --arg Address:{0} --arg Int:100 --signer emulator-oracle-deployer'.format(
        poolAddr)
    print(cmd)
    os.system(cmd)
    # update speficied feed
    feedPrice = 14.15
    if poolName in setting.PoolParams:
        feedPrice = setting.PoolParams[poolName]['OraclePrice']
    cmd = 'flow transactions send cadence/transactions/Oracle/updater_upload_feed_data.cdc --arg Address:{0} --arg UFix64:{1} --signer emulator-oracle-updater'.format(
        poolAddr, feedPrice)
    print(cmd)
    os.system(cmd)



# init comptroller
oracle_deployer_addr = setting.DictDeployNameToAddr['emulator-oracle-deployer']
os.system('flow transactions send ./cadence/transactions/Comptroller/init_comptroller.cdc --arg Address:{0} --signer emulator-account'.format(oracle_deployer_addr))

# init pools
print('-------------', 'init pools')
for name in setting.PoolNames+setting.FakePoolNames:
    interestModeAddr = setting.DictDeployNameToAddr['emulator-account']
    comptrollerAddr = setting.DictDeployNameToAddr['emulator-account']
    initContractName = 'init_pool_'+name
    deployerName = 'emulator-pool-tmpdeployer-'+name
    reserveFactor = 0.01
    poolSeizeShare = 0.028
    if name in setting.PoolParams:
        reserveFactor = setting.PoolParams[name]['reserveFactor']
        poolSeizeShare = setting.PoolParams[name]['poolSeizeShare']
    cmd = 'flow transactions send ./cadence/transactions/Pool/autogen/{0}.cdc -f flow_multipool.json --arg Address:{1} --arg Address:{2} --arg UFix64:{3} --arg UFix64:{4} --signer {5}'.format(
        initContractName, interestModeAddr, comptrollerAddr, reserveFactor, poolSeizeShare, deployerName)
    print(cmd)
    os.system(cmd)

# add markets
for poolName in setting.PoolNames+setting.FakePoolNames:
    poolAddr = setting.DictPoolNameToAddr[poolName]
    collateralFactor = 0.75
    borrowCap = 100.0
    if poolName in setting.PoolParams:
        collateralFactor = setting.PoolParams[poolName]['collateralFactor']
        borrowCap = setting.PoolParams[poolName]['borrowCap']
    cmd = 'flow transactions send ./cadence/transactions/Comptroller/add_market.cdc --arg Address:{0} --arg UFix64:{1} --arg UFix64:{2} --arg Bool:true --arg Bool:true --signer emulator-account'.format(
        poolAddr, collateralFactor, borrowCap
    )
    print(cmd)
    os.system(cmd)


# test mint for user
userAddr = '0xe03daebed8ca0615'
os.system('flow transactions send ./cadence/transactions/Test/emulator_flow_transfer.cdc {0} --signer emulator-account'.format(userAddr))
os.system('flow transactions send ./cadence/transactions/Test/mint_fusd_for_user.cdc --signer emulator-user-A --arg UFix64:\"100.0\"')
for fakeName in setting.FakePoolNames:
    os.system('flow transactions send ./cadence/transactions/Test/autogen/mint_{0}_for_user.cdc -f flow_multipool.json --signer emulator-user-A'.format(fakeName))