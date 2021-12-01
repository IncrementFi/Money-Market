global NetworkType
global PoolNames
global FakePoolNames
global PoolParams
global BuildinAddr
global PoolAddrs
global DictPoolNameToAddr
global DictDeployNameToAddr
global DictPoolNameToDeployName

NetworkType = "emulator" # "testnet"

# PoolNames's token file should already be created in contracts.
PoolNames = ['FUSD', 'FlowToken']

# FakePool's token contract will be generated automatically
# FakePoolNames = ['Apple', 'Banana', 'Peach']
FakePoolNames = ['Apple']



PoolParams = {}
PoolParams['FUSD']       = { 'reserveFactor':0.01, 'poolSeizeShare':0.028, 'OraclePrice':1.0, 'liquidationPenalty':0.05, 'collateralFactor':0.80, 'borrowCap':100000000.0 }
PoolParams['FlowToken']  = { 'reserveFactor':0.01, 'poolSeizeShare':0.028, 'OraclePrice':14.15, 'liquidationPenalty':0.05, 'collateralFactor':0.80, 'borrowCap':100000000.0 }
PoolParams['Apple']      = { 'reserveFactor':0.01, 'poolSeizeShare':0.028, 'OraclePrice':10.0, 'liquidationPenalty':0.05, 'collateralFactor':0.80, 'borrowCap':100000000.0 }



BuildinAddr = [
    '0x01cf0e2f2f715450',
    '0x179b6b1cb6755e31',
    '0xf3fcd2c1a78f5eee',
    '0xe03daebed8ca0615',
    '0x045a1763c93006ca',
    '0x120e725050340cab',
    '0xf669cb8d41ce0c74'
]
PoolAddrs = []
DictPoolNameToAddr = {}
DictDeployNameToAddr = {}
DictPoolNameToDeployName = {}

