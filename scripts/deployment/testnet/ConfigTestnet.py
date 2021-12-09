import json
import re

global EmptyPath
global UnreadablePath


EmptyPath = './scripts/deployment/testnet/cadence_empty'
UnreadablePath = './scripts/deployment/testnet/cadence_unreadable'

P = ['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z']
C = ['f','o','b','c','d','e','p','y','z','q','r','s','g','h','i','j','k','l','m','n','t','u','a','v','w','x']

def Encrypt(w):
    ww = w[::-1] 
    for i in range(0, 10):
        ww = ww.replace(str(i), chr(ord('a')+i))
    l = len(ww)
    #ww = ww[:int(l/2)] + ww[int(l/3):] + ww + ww[int(l/4) : int(l/4*3)]
    for i in range(0, len(P)):
        ww = ww.replace(P[i], C[i])
    return ww

def ExtractPoolDeployers(network):
    PoolDeployerNameToAddr = {}
    with open('./flow.json', 'r') as f:
        flow_dict = json.load(f)
        for deployer in flow_dict['pools'][network]:
            PoolDeployerNameToAddr[deployer] = flow_dict['accounts'][deployer]['address']
    return PoolDeployerNameToAddr

def ExtractPoolNames(network):
    PoolNameToAddr = {}
    with open('./flow.json', 'r') as f:
        flow_dict = json.load(f)
        for deployer in flow_dict['pools'][network]:
            poolName = flow_dict['pools'][network][deployer]['poolName']
            PoolNameToAddr[poolName] = flow_dict['accounts'][deployer]['address']

    return PoolNameToAddr


def ExtractInterestDeployers(network):
    InterestDeployerNameToAddr = {}
    with open('./flow.json', 'r') as f:
        flow_dict = json.load(f)
        for deployer in flow_dict['interest-rate-models'][network]:
            InterestDeployerNameToAddr[deployer] = flow_dict['accounts'][deployer]['address']
    return InterestDeployerNameToAddr

def ExtractOracleDeployer():
    return 'testnet-oracle-deployer'
    
def ExtractOracleUpdater():
    return 'testnet-oracle-updater'

def ExtractComptrollerDeployer():
    return 'testnet-comptroller-deployer'

def ExtractPoolConfig(poolDeployer, network):
    with open('./flow.json', 'r') as f:
        flow_dict = json.load(f)
        return flow_dict["pools"][network][poolDeployer]

def ExtractPoolConfigByPoolName(poolName, network):
    res = None
    with open('./flow.json', 'r') as f:
        flow_dict = json.load(f)
        for poolDeployer in flow_dict["pools"][network]:
            if flow_dict["pools"][network][poolDeployer]['poolName'] == poolName:
                res = flow_dict["pools"][network][poolDeployer]
        return res

def ExtractInterestConfig(interestDeployer, network):
    with open('./flow.json', 'r') as f:
        flow_dict = json.load(f)
        return flow_dict["interest-rate-models"][network][interestDeployer]

def ExtractContractNameToAddress(flow_json_path):
    ContractNameToAddress = {}
    with open(flow_json_path, 'r') as f:
        flow_dict = json.load(f)
        # extract from deployment config
        for deployer in flow_dict['deployments']['testnet']:
            for contractName in flow_dict['deployments']['testnet'][deployer]:
                ContractNameToAddress[contractName] = flow_dict['accounts'][deployer]['address']
        # extract from contract config
        for contractName in flow_dict['contracts']:
            if not isinstance(flow_dict['contracts'][contractName], str):
                testnetAddr = flow_dict['contracts'][contractName]['aliases']['testnet']
                if testnetAddr != None:
                    ContractNameToAddress[contractName] = testnetAddr
    return ContractNameToAddress

def ExtractDeployerToAddress(flow_json_path):
    DeployerToAddress = {}
    with open(flow_json_path, 'r') as f:
        flow_dict = json.load(f)
        # extract from deployment config
        for deployer in flow_dict['accounts']:
            DeployerToAddress[deployer] = flow_dict['accounts'][deployer]['address']

    return DeployerToAddress


def ReplaceImportPathTo0xName(code):
    # "import aaa from ./../../contract/aaa.cdc" => "import aaa from 0xaaa"
    pattern = re.compile(r'from \"[.\/]+.*\/(.*).cdc\"')
    res = re.sub(pattern, r"from 0x\1", code)
    return res

def Replace0xNameTo0xAddress(code, NameToAddressDict):
    res = code
    for contractName in NameToAddressDict:
        res = res.replace("0x"+contractName, NameToAddressDict[contractName])
    return res