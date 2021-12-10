import os
import sys
import json
import shutil
import re
import ConfigTestnet

Keywords = {}
WhiteFileList = { 'FlowToken.cdc', 'FungibleToken.cdc', 'FUSD.cdc', 'Kibble.cdc', 'FBTC.cdc', 'FETH.cdc' }
WhiteKeywords = { 'borrow', 'timestamp', 'deposit', 'balance', 'withdraw', 'err' }



if os.path.exists(ConfigTestnet.UnreadablePath):
    shutil.rmtree(ConfigTestnet.UnreadablePath)
os.makedirs(ConfigTestnet.UnreadablePath)
if os.path.exists(ConfigTestnet.EmptyPath):
    shutil.rmtree(ConfigTestnet.EmptyPath)
os.makedirs(ConfigTestnet.EmptyPath)


def ExtractContractName(line):
    variable_reg = re.compile(r'pub contract interface (.+?)\b[:=<{\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()
    variable_reg = re.compile(r'pub contract (.+?)\b[:=<{\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()
    variable_reg = re.compile(r'pub resource interface (.+?)\b[:=<{\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()
    variable_reg = re.compile(r'pub resource (.+?)\b[:=<{\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()
    return None

def ExtractVariable(line):
    variable_reg = re.compile(r'\blet\b (.+?)\b[:=<\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'\bvar\b (.+?)\b[:=<\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'pub case (.+?)\b[:=<\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'pub struct (.+?)\b[:=<{\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'pub enum (.+?)\b[:=<\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'\bfun\b (.+?)\b[(:=<\n]*')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    return None

def ExtractMsgStr(line):
    variable_reg = re.compile(r'\bmsg:\s*\"(.*)\",')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'\bmessage:\s*\"(.*)\"')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()

    variable_reg = re.compile(r'\bpanic\b\(\"(.*)\"')
    res = variable_reg.search(line)
    if res != None: return res[1].strip()


commet_start = False
def FilterLine(line):
    global commet_start
    line = line.strip()
    if line.startswith('//'): line = ""
    if line.startswith('log('): line = ""
    if line.startswith('/*'):
        commet_start = True
        return ""
    if commet_start == True:
        if line.find('*/') >= 0:
            commet_start = False
        return ""
    return line


def ExtractKeywordsFromFile(filePath):
    with open(filePath, 'r') as f:
        for line in f:
            line = FilterLine(line)
            if len(line) == 0: continue
            
            variable = ExtractVariable(line)
            if variable != None and variable not in WhiteKeywords:
                Keywords[variable] = "?"
            msg = ExtractMsgStr(line)
            if msg != None and msg not in WhiteKeywords:
                Keywords[msg] = "?"


def ReplaceKeywords(line, keywords):
    sortKeys =  sorted(keywords, key=lambda k: len(k), reverse=True)
    for keyword in sortKeys:
        reg = re.compile(r'\b%s\b'%keyword)
        line = reg.sub(keywords[keyword], line)
    return line


# extract all Keywords in only contracts' cdc files.
files = os.walk('./cadence/contracts')
for path, dir_list, file_list in files:
    if path.find('autogen') >= 0: continue

    for file_name in file_list:
        if file_name in WhiteFileList: continue    
        
        file_path = os.path.join(path, file_name)
        if file_path.endswith('.cdc'):
            print(file_path)
            ExtractKeywordsFromFile(file_path)

# encrypte Keywords
for w in Keywords:
    Keywords[w] = ConfigTestnet.Encrypt(w)

# mix contracts, transactions, scripts
replace_files = os.walk('./cadence')
for path, dir_list, file_list in replace_files:
    if path.find('autogen') >= 0: continue
    write_path = path.replace('cadence', ConfigTestnet.UnreadablePath)
    if not os.path.exists(write_path):
        os.makedirs(write_path)
    for file_name in file_list:
        file_path = os.path.join(path, file_name)
        if file_path.endswith('.cdc') == False: continue
        if file_name in WhiteFileList:
            write_file_path = os.path.join(write_path, file_name)
            shutil.copyfile(file_path, write_file_path)
            continue

        code = ""
        with open(file_path, 'r') as f:
            pre_line = ""
            for line in f:
                ori_line = line
                line = FilterLine(line)
                if len(line) == 0: continue
                
                replace_line = ReplaceKeywords(line, Keywords)
                end_char = '\n'
                if pre_line.endswith(',') or \
                    pre_line.endswith('{') or \
                    pre_line.endswith('(') or \
                    pre_line.endswith('+') or \
                    pre_line.endswith('*') or \
                    pre_line.endswith('-') or \
                    pre_line.endswith('/') or \
                    pre_line.endswith('=') or \
                    pre_line.endswith(':') or \
                    pre_line.endswith('[') or \
                    replace_line.startswith(')') or \
                    replace_line.startswith('.') or \
                    replace_line.startswith('??') or \
                    replace_line.startswith(']') or \
                    replace_line.startswith('}'):
                    end_char = ''
                elif replace_line.startswith('let ') or \
                    replace_line.startswith('pub') or \
                    replace_line.startswith('var ') or \
                    replace_line.startswith('{{{{') or \
                    replace_line.startswith('self.') or \
                    replace_line.startswith('access') or \
                    replace_line.startswith('if') or \
                    replace_line.startswith('return') or \
                    replace_line.startswith('assert') or \
                    replace_line.startswith('while') or \
                    replace_line.startswith('init') or \
                    replace_line.startswith('destroy') or \
                    replace_line.startswith('emit') or \
                    replace_line.startswith('LendingPool.') or \
                    pre_line.endswith(')'):
                    end_char = ';'
                if path.find('contracts') < 0:
                    end_char = '\n'
                if pre_line.find('//') >= 0:
                    end_char = '\n'
                    # TODO add space before lines
                    #ori_line.find(replace_line[0])
                if code == "": end_char = ""
                code = code + end_char + replace_line
                pre_line = line
  
        encrypt_file_name = file_name
        if file_name[:-4] in Keywords:
            encrypt_file_name = Keywords[file_name[:-4]] + '.cdc'
        write_file_path = os.path.join(write_path, encrypt_file_name)
        with open(write_file_path, 'w') as fw:
            fw.write(code)

# generate empty cdcs
replace_files = os.walk('./cadence/contracts')
for path, dir_list, file_list in replace_files:
    if path.find('autogen') >= 0: continue
    write_path = path.replace('cadence', ConfigTestnet.EmptyPath)
    if not os.path.exists(write_path):
        os.makedirs(write_path)
    for file_name in file_list:
        file_path = os.path.join(path, file_name)
        if file_path.endswith('.cdc') == False: continue
        if file_name in WhiteFileList: continue

        code = ""
        inInit = False
        with open(file_path, 'r') as f:
            for line in f:
                ori_line = line
                line = ori_line.strip()
                if len(line) == 0: continue
                
                if line.startswith('pub contract interface'):   
                    keyword = ExtractContractName(line)
                    line = 'pub contract interface ' + keyword + '{\n' 
                elif line.startswith('pub contract'):
                    keyword = ExtractContractName(line)
                    line = 'pub contract ' + keyword + '{\n' 
                elif line.startswith('pub resource interface'):
                    keyword = ExtractContractName(line)
                    line = 'pub resource interface ' + keyword + '{}\n'
                elif line.startswith('pub resource'):
                    keyword = ExtractContractName(line)
                    line = 'pub resource ' + keyword + '{}\n'
                elif line.startswith('pub struct'):
                    keyword = ExtractVariable(line)
                    line = 'pub struct ' + keyword + '{}\n'
                elif ori_line.startswith('    pub') and line.endswith('StoragePath'):
                    line = line + '\n'
                elif ori_line.startswith('    init('):
                    inInit = True
                    line = 'init(){\n'
                elif inInit == True:
                    if len(line) < 3 and line.endswith('}'):
                        inInit = False
                        line = line + '\n'
                    elif line.find('/storage/')>=0:
                        line = line + '\n'
                    elif line.startswith('destroy'):
                        line = line + '\n'
                    else:
                        continue
                else:
                    continue

                replace_line = ReplaceKeywords(line, Keywords)
                code = code + replace_line
            code = code + '}\n'
  
        empty_file_name = file_name
        if file_name[:-4] in Keywords:
            empty_file_name = Keywords[file_name[:-4]] + '.cdc'
        write_file_path = os.path.join(write_path, empty_file_name)
        with open(write_file_path, 'w') as fw:
            fw.write(code)

# create flow.unreadable.json
FileNameToEncryptName = {}
EncryptNameToAddr = {}
with open('./flow.json', 'r') as f:
    flow_dict = json.load(f)
    for contractName in flow_dict['contracts']:
        if contractName in Keywords:
            FileNameToEncryptName[contractName] = Keywords[contractName]
with open('./scripts/deployment/testnet/flow.unreadable.json', 'w') as fw:
    with open('./flow.json', 'r') as f:
        for line in f:
            line = line.replace('./cadence/contracts/', ConfigTestnet.UnreadablePath+'/contracts/')
            for contractName in FileNameToEncryptName:
                line = re.sub(r'\b%s\b'%contractName, FileNameToEncryptName[contractName],line)
            fw.write(line)

# create flow.empty.json
with open('./scripts/deployment/testnet/flow.empty.json', 'w') as fw:
    with open('./scripts/deployment/testnet/flow.unreadable.json', 'r') as f:
        for line in f:
            line = line.replace('cadence_unreadable', 'cadence_empty')
            fw.write(line)


PoolDeployerNameToAddr = ConfigTestnet.ExtractPoolDeployers('testnet')
InterestDeployerNameToAddr = ConfigTestnet.ExtractInterestDeployers('testnet')

ContractNameToAddress = ConfigTestnet.ExtractContractNameToAddress('./scripts/deployment/testnet/flow.unreadable.json')
PoolNameToAddr = ConfigTestnet.ExtractPoolNames('testnet')
PoolContractName = ConfigTestnet.GetLendingPoolContractName()
ComptrollerContractName = ConfigTestnet.GetComptrollerContractName()
InterestContractName = ConfigTestnet.GetInterestContractName()


# gen contracts: InterestRateModel with address
gen_base_path = ConfigTestnet.UnreadablePath + '/contracts'
with open(gen_base_path + '/'+InterestContractName+'.cdc', 'r') as f:
    code_template = f.read()
write_path = gen_base_path + '/autogen'
if not os.path.exists(write_path): os.makedirs(write_path)
with open(write_path+'/{0}.cdc.addr'.format(InterestContractName), 'w') as fw:
    code = code_template
    code = ConfigTestnet.ReplaceImportPathTo0xName(code)
    code = ConfigTestnet.Replace0xNameTo0xAddress(code, ContractNameToAddress)
    fw.write(code)


# gen tmp transactions: create_interest_rate_model
gen_base_path = ConfigTestnet.UnreadablePath + '/transactions/InterestRateModel'
if os.path.exists( gen_base_path + '/autogen' ): shutil.rmtree(gen_base_path + '/autogen')
with open(gen_base_path + '/create_interest_rate_model.cdc', 'r') as f:
    code_template = f.read()

for interestDeployer in InterestDeployerNameToAddr:
    write_path = gen_base_path + '/autogen'
    if not os.path.exists(write_path): os.makedirs(write_path)

    with open(write_path+'/create_interest_rate_model.cdc.{0}.tmp'.format(interestDeployer), 'w') as fw:
        code = code_template
        code = ConfigTestnet.ReplaceImportPathTo0xName(code)
        tmpDict = ContractNameToAddress.copy()
        # specify the interest contract addr
        tmpDict[InterestContractName] = InterestDeployerNameToAddr[interestDeployer]
        code = ConfigTestnet.Replace0xNameTo0xAddress(code, tmpDict)
        
        fw.write(code)

# gen tmp transactions: prepare_template_for_pool
gen_base_path = ConfigTestnet.UnreadablePath + '/transactions/Pool'
if os.path.exists( gen_base_path + '/autogen' ): shutil.rmtree(gen_base_path + '/autogen')
with open(gen_base_path + '/prepare_template_for_pool.cdc', 'r') as f:
    code_template = f.read()

for poolDeployer in PoolDeployerNameToAddr:
    write_path = gen_base_path + '/autogen'
    if not os.path.exists(write_path): os.makedirs(write_path)

    with open(write_path+'/prepare_template_for_pool.cdc.{0}.tmp'.format(poolDeployer), 'w') as fw:
        code = code_template
        code = ConfigTestnet.ReplaceImportPathTo0xName(code)
        tmpDict = ContractNameToAddress.copy()
        # specify the interest contract addr
        tmpDict[PoolContractName] = PoolDeployerNameToAddr[poolDeployer]
        code = ConfigTestnet.Replace0xNameTo0xAddress(code, tmpDict)
        
        fw.write(code)

# gen tmp transactions: init_pool_template
gen_base_path = ConfigTestnet.UnreadablePath + '/transactions/Pool'
with open(gen_base_path + '/init_pool_template.cdc', 'r') as f:
    code_template = f.read()

for poolDeployer in PoolDeployerNameToAddr:
    write_path = gen_base_path + '/autogen'
    if not os.path.exists(write_path): os.makedirs(write_path)

    with open(write_path+'/init_pool_template.cdc.{0}.tmp'.format(poolDeployer), 'w') as fw:
        code = code_template
        code = ConfigTestnet.ReplaceImportPathTo0xName(code)
        tmpDict = ContractNameToAddress.copy()
        # specify the interest contract addr
        tmpDict[PoolContractName] = PoolDeployerNameToAddr[poolDeployer]
        code = ConfigTestnet.Replace0xNameTo0xAddress(code, tmpDict)
        
        fw.write(code)

# gen contracts: LendingPool with addr
gen_base_path = ConfigTestnet.UnreadablePath + '/contracts'
with open(gen_base_path + '/'+PoolContractName+'.cdc', 'r') as f:
    code_template = f.read()
write_path = gen_base_path + '/autogen'
if not os.path.exists(write_path): os.makedirs(write_path)

with open(write_path+'/{0}.cdc.addr'.format(PoolContractName), 'w') as fw:
    code = code_template
    code = ConfigTestnet.ReplaceImportPathTo0xName(code)
    code = ConfigTestnet.Replace0xNameTo0xAddress(code, ContractNameToAddress)
    
    fw.write(code)


# gen deploy.config.testnet.json
with open('./scripts/deployment/testnet/flow.unreadable.json', 'r') as f:
    flow_dict = json.load(f)
configJson = {}
#
configJson["ComptrollerAddress"] = ContractNameToAddress[ComptrollerContractName]
#
configJson["ContractAddress"] = {}
for contract in ContractNameToAddress:
    configJson["ContractAddress"][contract] = ContractNameToAddress[contract]
#
configJson["PoolAddress"] = {}
configJson["PoolName"] = {}

for poolName in PoolNameToAddr:
    poolConfig = ConfigTestnet.ExtractPoolConfigByPoolName(poolName, 'testnet')
    poolAddr = PoolNameToAddr[poolName]
    poolContract = PoolContractName
    poolTokenName = poolName
    if poolName == "FlowToken": poolTokenName = "Flow"
    lowerPoolName = poolConfig['tokenNameLower']
    info = {
        "PoolContract": poolContract,
        "PoolName": poolName,
        "LowerPoolName": lowerPoolName,
        "TokenName": poolTokenName,
        "VaultBalancePath": lowerPoolName+"Balance",
        "TokenAddress": configJson["ContractAddress"][poolName],
        "PoolAddress":  poolAddr,
        "Fake": poolConfig['isFake']
    }
    configJson["PoolAddress"][poolAddr] = info
    configJson["PoolName"][poolName] = info

##
configJson["Codes"] = {}
configJson["Codes"]["Scripts"] = {}

scriptsCodePath = [
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_all_markets.cdc',
        'name': 'QueryAllMarkets'
    },
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_market_info.cdc',
        'name': 'QueryMarketInfo'
    },
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_user_all_pools.cdc',
        'name': 'QueryUserAllPools'
    },
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_user_pool_info.cdc',
        'name': 'QueryUserPoolInfo'
    },
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_vault_balance.cdc',
        'name': 'QueryVaultBalance'
    },
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_user_position.cdc',
        'name': 'QueryUserPosition'
    },
    {
        'path': './scripts/deployment/testnet/cadence_unreadable/scripts/Query/query_market_interestrate_model_params.cdc',
        'name': 'QueryMarketInterestRateModelParams'
    },
    {
        "path" : "./scripts/deployment/testnet/cadence_unreadable/scripts/Oracle/get_feed_latest_result.cdc",
        "name" : "GetSimpleOracleFeedLatestResult"
    }
]
for item in scriptsCodePath:
    path = item["path"]
    name = item["name"]
    with open(path, 'r') as f:
        code = f.read()
        code = ConfigTestnet.ReplaceImportPathTo0xName(code)
        code = ConfigTestnet.Replace0xNameTo0xAddress(code, ContractNameToAddress)
        configJson["Codes"]["Scripts"][name] = code

configJson["Codes"]["Transactions"] = {}
poolCodePath = [
    {
        "path" : "./scripts/deployment/testnet/cadence_unreadable/transactions/User/user_deposit_template.cdc",
        "name" : "Deposit"
    },
    {
        "path" : "./scripts/deployment/testnet/cadence_unreadable/transactions/User/user_redeem_template.cdc",
        "name" : "Redeem"
    },
    {
        "path" : "./scripts/deployment/testnet/cadence_unreadable/transactions/User/user_borrow_template.cdc",
        "name" : "Borrow"
    },
    {
        "path" : "./scripts/deployment/testnet/cadence_unreadable/transactions/User/user_repay_template.cdc",
        "name" : "Repay"
    }
]

for item in poolCodePath:
    path = item["path"]
    name = item["name"]
    configJson["Codes"]["Transactions"][name] = {}
    with open(path, 'r') as f:
        poolTemplate = f.read()
        for poolName in configJson['PoolName']:
            code = poolTemplate
            code = code.replace('FlowToken', poolName)
            code = code.replace('flowToken', configJson['PoolName'][poolName]['LowerPoolName'])
            
            tmpDict = ContractNameToAddress.copy()
            # specify the pool contract addr
            tmpDict[PoolContractName] = PoolNameToAddr[poolName]
            code = ConfigTestnet.ReplaceImportPathTo0xName(code)
            code = ConfigTestnet.Replace0xNameTo0xAddress(code, tmpDict)
            
            configJson["Codes"]["Transactions"][name][poolName] = code

#
simpleOracleTransactionsPath = [
    {
        "path" : "./scripts/deployment/testnet/cadence_unreadable/transactions/Oracle/updater_upload_feed_data.cdc",
        "name" : "UpdaterUploadFeedData"
    }
]
configJson["Codes"]["Transactions"]["SimpleOracle"] = {}
for item in simpleOracleTransactionsPath:
    path = item["path"]
    name = item["name"]
    with open(path, 'r') as f:
        poolTemplate = f.read()
        
        code = poolTemplate
        code = ConfigTestnet.ReplaceImportPathTo0xName(code)
        code = ConfigTestnet.Replace0xNameTo0xAddress(code, ContractNameToAddress)
        
        configJson["Codes"]["Transactions"]["SimpleOracle"][name] = code

#                      
configJson["Codes"]["Transactions"]["Test"] = {}
with open(ConfigTestnet.UnreadablePath + '/transactions/Test/test_next_block.cdc', 'r') as f:
    code = f.read()
    code = ConfigTestnet.ReplaceImportPathTo0xName(code)
    code = ConfigTestnet.Replace0xNameTo0xAddress(code, ContractNameToAddress)
    configJson["Codes"]["Transactions"]["Test"]["NextBlock"] = code

for poolName in configJson['PoolName']:
    poolConfig = ConfigTestnet.ExtractPoolConfigByPoolName(poolName, 'testnet')
    if poolConfig['isFake'] == False: continue
    with open(ConfigTestnet.UnreadablePath + '/transactions/Test/mint_fusd_for_user.cdc', 'r') as f:
        code = f.read()
        code = code.replace('FUSD', poolName)
        code = code.replace('fusd', configJson['PoolName'][poolName]['LowerPoolName'])
        code = ConfigTestnet.ReplaceImportPathTo0xName(code)
        code = ConfigTestnet.Replace0xNameTo0xAddress(code, ContractNameToAddress)
        configJson["Codes"]["Transactions"]["Test"]["Mint"+poolName] = code
        print(code)


###
with open("./deploy.config.testnet.json", 'w') as fw:
    json_str = json.dumps(configJson, indent=2)
    fw.write(json_str)
