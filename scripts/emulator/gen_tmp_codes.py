import os
import shutil
import multipool_setting as setting
import sys


# clear tmp files
if os.path.exists('./cadence/contracts/autogen'):
    shutil.rmtree('./cadence/contracts/autogen')
if os.path.exists('./cadence/transactions/Pool/autogen'):
    shutil.rmtree('./cadence/transactions/Pool/autogen')
if os.path.exists('./cadence/transactions/Test/autogen'):
    shutil.rmtree('./cadence/transactions/Test/autogen')
if os.path.exists('./cadence/transactions/User/autogen'):
    shutil.rmtree('./cadence/transactions/User/autogen')

if len(sys.argv) > 1 and sys.argv[1] == '1':
    os.system('rm flow_multipool*')
    exit()

# generate fake pool token contracts: Apple.cdc, Peach.cdc
with open('./cadence/contracts/FUSD.cdc', 'r') as f:
    token_template = f.read()
for name in setting.FakePoolNames:
    tokenContractName = name
    token_contract = token_template
    token_contract = token_contract.replace('./FungibleToken.cdc', '../FungibleToken.cdc')
    token_contract = token_contract.replace('FUSD', tokenContractName)

    lowerName = tokenContractName[:1].lower() + tokenContractName[1:]
    if tokenContractName == 'FUSD':
        lowerName = lowerName.lower()
    token_contract = token_contract.replace('fusd', lowerName)
    path = './cadence/contracts/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/{0}.cdc'.format(tokenContractName), 'w') as fw:
        fw.write(token_contract)

## generate LendingPool contract
with open('./cadence/contracts/LendingPool.cdc', 'r') as f:
    pool_template = f.read()
for name in setting.PoolNames+setting.FakePoolNames:
    poolContractName = 'LendingPool_'+name
    pool_fusd = pool_template
    pool_fusd = pool_fusd.replace('./FungibleToken.cdc', '../../contracts/FungibleToken.cdc')
    pool_fusd = pool_fusd.replace('./Interfaces.cdc', '../../contracts/Interfaces.cdc')
    pool_fusd = pool_fusd.replace('./Config.cdc', '../../contracts/Config.cdc')
    pool_fusd = pool_fusd.replace('LendingPool', poolContractName)
    path = './cadence/contracts/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/{0}.cdc'.format(poolContractName), 'w') as fw:
        fw.write(pool_fusd)

# generate transactions
## generate pool preparations
with open('./cadence/transactions/Pool/prepare_vault_for_pool.template', 'r') as f:
    transaction_template = f.read()
for name in setting.PoolNames:
    path = './cadence/transactions/Pool/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/prepare_{0}_vault_for_pool.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('POOLNAME', name)
        fw.write(fusd_vault)
for name in setting.FakePoolNames:
    path = './cadence/transactions/Pool/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/prepare_{0}_vault_for_pool.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('POOLNAME', name)
        fusd_vault = fusd_vault.replace('../contracts/', '../contracts/autogen/')
        fw.write(fusd_vault)

# generate init_pool_Apple.cdc, using template init_pool.template
with open('./cadence/transactions/Pool/init_pool.template', 'r') as f:
    transaction_template = f.read()
for name in setting.PoolNames+setting.FakePoolNames:
    path = './cadence/transactions/Pool/autogen'
    lendingPoolName = 'LendingPool_'+name
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/init_pool_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('LendingPool', lendingPoolName)
        fusd_vault = fusd_vault.replace('../../../contracts/', '../../../contracts/autogen/')
        fw.write(fusd_vault)



# generate test mint transactions
with open('./cadence/transactions/Test/mint_token_for_user.template', 'r') as f:
    transaction_template = f.read()
for name in setting.FakePoolNames:
    path = './cadence/transactions/Test/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/mint_{0}_for_user.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FUSD', name)
        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('fusd', lowerName)
        fw.write(fusd_vault)

#generate user_deposit_fusd.cdc
with open('./cadence/transactions/User/user_deposit.template', 'r') as f:
    transaction_template = f.read()
for name in setting.FakePoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_deposit_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/'+name, '../contracts/autogen/'+name)
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)
for name in setting.PoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_deposit_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)

#generate user_redeem_fusd.cdc
with open('./cadence/transactions/User/user_redeem.template', 'r') as f:
    transaction_template = f.read()
for name in setting.FakePoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_redeem_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/'+name, '../contracts/autogen/'+name)
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)
for name in setting.PoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_redeem_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)

#generate user_borrow_fusd.cdc
with open('./cadence/transactions/User/user_borrow.template', 'r') as f:
    transaction_template = f.read()
for name in setting.FakePoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_borrow_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/'+name, '../contracts/autogen/'+name)
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)
for name in setting.PoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_borrow_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)

#generate user_repay_fusd.cdc
with open('./cadence/transactions/User/user_repay.template', 'r') as f:
    transaction_template = f.read()
for name in setting.FakePoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_repay_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/'+name, '../contracts/autogen/'+name)
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)
for name in setting.PoolNames:
    path = './cadence/transactions/User/autogen'
    if not os.path.exists(path):
        os.makedirs(path)
    with open(path+'/user_repay_{0}.cdc'.format(name), 'w') as fw:
        fusd_vault = transaction_template
        fusd_vault = fusd_vault.replace('FlowToken', name)

        lowerName = name[:1].lower() + name[1:]
        if name == 'FUSD':
            lowerName = lowerName.lower()
        fusd_vault = fusd_vault.replace('flowToken', lowerName)
        fusd_vault = fusd_vault.replace('LendingPool', 'LendingPool_'+name)
        fusd_vault = fusd_vault.replace('../contracts/', '../../contracts/')
        fusd_vault = fusd_vault.replace('../contracts/LendingPool', '../contracts/autogen/LendingPool')
        fw.write(fusd_vault)