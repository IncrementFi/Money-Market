import chain
import asyncio
import random

class Agent:
    _activate = False
    _userAddr = ""
    _userInfo = {}
    
    def __init__(self, initVault):
        # create account
        self._userAddr = chain.CreateAccount()
        if len(self._userAddr) > 8 and len(self._userAddr) < 20:
            self._activate = True
        else: return
        print('Create Agent ',self._userAddr)
        
        # mint
        for i in range(0, len(chain.PoolAddrs)):
            poolAddr = chain.PoolAddrs[i]
            poolName = chain.ConfigJson['PoolAddress'][poolAddr]['PoolName']
            chain.Faucet(poolName, self._userAddr, str(float(initVault)))
    
    async def UpdateRealData(self):
        self._userInfo = await chain.QueryUserInfo(self._userAddr)

    def LiquidationCheck(self):
        totalSupplyUsd = 0.0
        totalBorrowUsd = 0.0
        if self._userInfo == {}: return 0.0,0.0
        for poolAddr in chain.PoolAddrs:
            oraclePrice = float(chain.PoolInfos[poolAddr]['marketOraclePriceUsd'])/1e18
            marketCollateralFactor = float(chain.PoolInfos[poolAddr]['marketCollateralFactor'])/1e18
            userSupply = self._userInfo[poolAddr]['userSupply'] * oraclePrice * marketCollateralFactor
            userBorrow = self._userInfo[poolAddr]['userBorrow'] * oraclePrice
            totalSupplyUsd = totalSupplyUsd + userSupply
            totalBorrowUsd = totalBorrowUsd + userBorrow
        return totalSupplyUsd, totalBorrowUsd
    
    def Update(self):
        info = self._userInfo

class RandomAgent(Agent):
    def __init__(self):
        initVault = random.randint(100, 1000000)
        Agent.__init__(self, initVault)


    async def Update(self):
        #print(self._userAddr, 'update')
        await self.UpdateRealData()

        poolCount = len(chain.PoolAddrs)
        poolSelect = random.randint(0, poolCount-1)
        poolAddr = chain.PoolAddrs[poolSelect]
        poolName = chain.ConfigJson['PoolAddress'][poolAddr]['PoolName']
        poolVault = self._userInfo[poolAddr]['LocalVault']
        behavior = random.randint(0, 4)
        if behavior == 0:
            if poolVault < 0.1: return
            amount = random.randint(int(poolVault*0.1), int(poolVault*0.5))
            print('Agent', self._userAddr, 'deposit randomly', amount, 'max deposit:', poolVault)
            chain.Deposit(poolName, self._userAddr, float(amount))
        elif behavior == 1:
            totalSupplyUsd, totalBorrowUsd = self.LiquidationCheck()
            oraclePrice = float(chain.PoolInfos[poolAddr]['marketOraclePriceUsd'])/1e18
            redeemMax = (totalSupplyUsd - totalBorrowUsd) / oraclePrice
            curSupply = self._userInfo[poolAddr]['userSupply']
            poolCash = (float(chain.PoolInfos[poolAddr]['marketSupplyScaled'])-float(chain.PoolInfos[poolAddr]['marketBorrowScaled']))/1e18
            if redeemMax > curSupply: redeemMax = curSupply
            if redeemMax > poolCash: redeemMax = poolCash
            if redeemMax < 0.1: return
            amount = random.randint(int(redeemMax/10), int(redeemMax))
            print('Agent', self._userAddr, 'redeem randomly', amount, 'redeem max:', redeemMax)
            chain.Redeem(poolName, self._userAddr, float(amount))
        elif behavior == 2:
            totalSupplyUsd, totalBorrowUsd = self.LiquidationCheck()
            oraclePrice = float(chain.PoolInfos[poolAddr]['marketOraclePriceUsd'])/1e18
            borrowMax = (totalSupplyUsd - totalBorrowUsd) / oraclePrice
            poolCash = (float(chain.PoolInfos[poolAddr]['marketSupplyScaled'])-float(chain.PoolInfos[poolAddr]['marketBorrowScaled']))/1e18
            if borrowMax > poolCash: borrowMax = poolCash
            if borrowMax < 0.1: return
            amount = random.randint(int(borrowMax*0.1), int(borrowMax*0.8))
            print('Agent', self._userAddr, 'borrow randomly', amount, ' borrow max:', borrowMax)
            chain.Borrow(poolName, self._userAddr, float(amount))
        elif behavior == 3:
            curBorrow = self._userInfo[poolAddr]['userBorrow']
            poolVault = self._userInfo[poolAddr]['LocalVault']
            repayMaxAmount = curBorrow
            if repayMaxAmount > poolVault: repayMaxAmount = poolVault
            if repayMaxAmount < 0.1: return
            amount = random.randint(int(repayMaxAmount/10), int(repayMaxAmount))
            print('Agent', self._userAddr, 'repay randomly', amount, ' max:', repayMaxAmount)
            chain.Repay(poolName, self._userAddr, float(amount))