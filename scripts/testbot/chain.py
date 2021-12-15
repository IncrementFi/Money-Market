import matplotlib.pyplot as plt
import numpy as np
import asyncio
import os
import math
import json
from flow_py_sdk import flow_client, cadence, Script

global UserList
global PoolAddrs
global PoolInfos
global ConfigJson
global BlockHeight

host = '127.0.0.1'
port = '3569'
js_path = 'scripts/testbot/api/js/'

UserList = []
PoolAddrs = []
PoolInfos = {}
CurUserAddr = ""
CurUserInfo = {}
BlockHeight = 0
ConfigJson = None

with open('./deploy.config.emulator.json', 'r') as f:
    ConfigJson = json.load(f)

async def QueryBlockInfo():
    global BlockHeight
    async with flow_client(host=host, port=port) as client:
        block = await client.get_latest_block(is_sealed=False)
        BlockHeight = block.height

#
async def QueryAllMarkets():
    code = ConfigJson['Codes']['Scripts']['QueryAllMarkets']
    auditAddr = ConfigJson["ContractAddress"]["ComptrollerV1"]
    script = Script(
        code = code,
        arguments=[cadence.Address.from_hex(auditAddr)]
    )
    async with flow_client(host=host, port=port) as client:
        global PoolAddrs
        res = await client.execute_script(script=script)
        list = res.as_type(cadence.Array).value
        PoolAddrs = []
        for item in list:
            addr_str = item.hex_with_prefix()
            PoolAddrs.append(addr_str)

#
async def QueryMarketInfo(poorAddr):
    global PoolInfos
    code = ConfigJson['Codes']['Scripts']['QueryMarketInfo']
    auditAddr = ConfigJson["ContractAddress"]["ComptrollerV1"]
    #poorAddr = '0x192440c99cb17282'

    script = Script(
        code = code,
        arguments=[
            cadence.Address.from_hex(poorAddr),
            cadence.Address.from_hex(auditAddr)
        ]
    )
    async with flow_client(host=host, port=port) as client:
        res = await client.execute_script(script=script)
        list = res.as_type(cadence.Dictionary).encode_value()['value']
        dict = {}
        for item in list:
            key = item['key']['value']
            dict[key] = item['value']['value']
        PoolInfos[dict['marketAddress']] = dict
        return dict

async def QueryUserPoolInfo(userAddr, poorAddr):
    global CurUserInfo
    code = ConfigJson['Codes']['Scripts']['QueryUserPoolInfo']
    auditAddr = ConfigJson["ContractAddress"]["ComptrollerV1"]

    script = Script(
        code = code,
        arguments=[
            cadence.Address.from_hex(userAddr),
            cadence.Address.from_hex(poorAddr),
            cadence.Address.from_hex(auditAddr)
        ]
    )
    async with flow_client(host=host, port=port) as client:
        res = await client.execute_script(script=script)
        list = res.as_type(cadence.Dictionary).encode_value()['value']
        dict = {}
        for item in list:
            key = item['key']['value']
            dict[key] = item['value']['value']
        if dict.__contains__('userSupplyScaled'):
            dict['userSupply'] = float(dict['userSupplyScaled'])/1e18
            dict['userBorrow'] = float(dict['userBorrowScaled'])/1e18
        else:
            dict['userSupply'] = 0.0
            dict['userBorrow'] = 0.0
        return dict

async def QueryUserLocalBalance(userAddr, poorAddr):
    global CurUserInfo
    code = ConfigJson['Codes']['Scripts']['QueryVaultBalance']
    path = ConfigJson["PoolAddress"][poorAddr]["VaultBalancePath"]

    script = Script(
        code = code,
        arguments=[
            cadence.Address.from_hex(userAddr),
            cadence.Path("public", path)
        ]
    )
    async with flow_client(host=host, port=port) as client:
        res = await client.execute_script(script=script)
        vaultAmount = res.as_type(cadence.UFix64).value/1e8
        return vaultAmount

async def UpdateAllMarketInfos():
    for poolAddr in PoolAddrs:
        await QueryMarketInfo(poolAddr)

async def QueryUserInfo(userAddr):
    userInfo = {}
    for poolAddr in PoolAddrs:
        info = await QueryUserPoolInfo(userAddr, poolAddr)
        userInfo[poolAddr] = info
        vaultAmount = await QueryUserLocalBalance(userAddr, poolAddr)
        userInfo[poolAddr]['LocalVault'] = vaultAmount
    return userInfo

async def UpdateCurUserInfo(userAddr):
    global CurUserAddr
    global CurUserInfo
    CurUserAddr = userAddr
    CurUserInfo = await QueryUserInfo(userAddr)

def CreateAccount():
    cmd = 'flow accounts create --key 99c7b442680230664baab83c4bc7cdd74fb14fb21cce3cceb962892c06d73ab9988568b8edd08cb6779a810220ad9353f8e713bc0cb8b81e06b68bcb9abb551e --sig-algo "ECDSA_secp256k1"  --signer "emulator-account"'
    res = os.popen(cmd).read()
    startIndex = res.index('\n\n\nAddress\t ') + 12
    endIndex = res.index('\nBalance\t ')
    addr = res[startIndex:endIndex]
    return addr

def Deposit(poolName, userAddr, amount):
    amount = round(float(amount), 8)
    cmd = 'node '+js_path+'deposit.js '+poolName+' '+userAddr+' '+str(amount)
    os.popen(cmd).read()
def Redeem(poolName, userAddr, amount):
    amount = round(float(amount), 8)
    cmd = 'node '+js_path+'redeem.js '+poolName+' '+userAddr+' '+str(amount)
    os.popen(cmd).read()
def Borrow(poolName, userAddr, amount):
    amount = round(float(amount), 8)
    cmd = 'node '+js_path+'borrow.js '+poolName+' '+userAddr+' '+str(amount)
    os.popen(cmd).read()
def Repay(poolName, userAddr, amount):
    amount = round(float(amount), 8)
    cmd = 'node '+js_path+'repay.js '+poolName+' '+userAddr+' '+str(amount)
    os.popen(cmd).read()
def Faucet(poolName, userAddr, amount):
    amount = round(float(amount), 8)
    cmd = 'node '+js_path+'faucet.js '+poolName+' '+userAddr+' '+str(amount)
    os.popen(cmd).read()
