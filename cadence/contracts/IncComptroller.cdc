import LedgerToken from "./LedgerToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import IncPoolInterface from "./IncPoolInterface.cdc"
import IncQueryInterface from "./IncQueryInterface.cdc"
import IncComptrollerInterface from "./IncComptrollerInterface.cdc"
pub contract IncComptroller: IncComptrollerInterface {

    // 对内审计接口

    // TODO 恶意用户 cap失效的处理

    //
    pub resource Comptroller: IncComptrollerInterface.ComptrollerPublic, IncComptrollerInterface.ComptrollerPrivate {
        // TODO 设置接口
        pub var liquidateCloseFactor: UFix64
        // 所有pool
        priv let poolCaps: {Address: Capability<&{IncPoolInterface.PoolPrivate}>}
        priv var poolCandidates: {Address: Capability<&{IncPoolInterface.PoolPrivate}>}
        
        //
        init() {
            self.liquidateCloseFactor = 0.5
            self.poolCaps = {}
            self.poolCandidates = {}
        }

        // 查询借款
        pub fun queryBorrowBalanceInAllPools(userAddr: Address): UFix64 {
            // TODO 测试函数 直接每个pool加和
            var borrowBalance = 0.0
            for poolCap in self.poolCaps.values {
                let borrow = poolCap.borrow()!.queryBorrowBalanceSnapshot(userAddr: userAddr)
                borrowBalance = borrowBalance + borrow
            }
            return borrowBalance
        }
        pub fun queryBorrowBalanceInPool(poolAddr: Address, userAddr: Address): UFix64 {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknown pool address."
            }
            return self.getPoolCap(poolAddr: poolAddr).borrow()!.queryBorrowBalanceSnapshot(userAddr: userAddr)
        }

        priv fun getPoolCap(poolAddr: Address): Capability<&{IncPoolInterface.PoolPrivate}> {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknown pool address"
            }
            return self.poolCaps[poolAddr]!
        }

        // pool申请加入市场
        pub fun applyForPoolList(poolCap: Capability<&{IncPoolInterface.PoolPrivate}>) {
            pre {
                self.poolCandidates.length <= 16: "Pending list is full."
                poolCap.check(): "Invalid pool cap."
                self.poolCandidates.containsKey(poolCap.borrow()!.owner!.address) == false: "Duplicate apply."
            }
            let poolAddress = poolCap.borrow()!.owner!.address
            log("新增 pool ".concat(poolAddress.toString()))
            self.poolCandidates.insert(key: poolAddress, poolCap)
        }

        // 处理pool入市请求
        pub fun approvePoolApplication(poolApproveAddrs: [Address]) {
            log("检查pool入市请求")
            for poolCap in self.poolCandidates.values {
                for approveAddr in poolApproveAddrs {
                    if poolCap.check() && poolCap.borrow()!.owner!.address == approveAddr {
                        if self.poolCaps.containsKey(approveAddr) == false {
                            log("通过入市请求 ".concat(approveAddr.toString()))
                            self.poolCaps.insert(key: approveAddr, poolCap)
                            poolCap.borrow()!.openPool(true)
                            // TODO Event
                        } else if self.poolCaps[approveAddr]!.check() == false {
                            log("更新pool cap: pool ".concat(approveAddr.toString()))
                            self.poolCaps.remove(key: approveAddr)
                            self.poolCaps.insert(key: approveAddr, poolCap)
                            poolCap.borrow()!.openPool(true)
                            // TODO Event
                        }
                    }
                }
            }
            self.poolCandidates = {}
        }

        
        // TODO 退出市场
        // TODO 临时关闭市场
        pub fun userExitMarket() {

        }
        // TODO 用户加入市场
        pub fun userEnterPool() {
            // TODO 主动长传在本地创建的该市场ctoken
            // TODO pool -> user1 user2 user3
            // TODO user -> pool1 pool2 pool3 
        }

        pub fun minterAllowed(poolAddr: Address, inUnderlyingVault: &FungibleToken.Vault, outOverlyingVaultCap: Capability<&{LedgerToken.PrivateCertificate}>) {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknow pool."
            }
            
            // 大部分检测交由pool负责
            let userAddr = outOverlyingVaultCap.borrow()!.owner!.address

            // 检查该用户是否行为异常
            // 即便异常, 存钱还是允许的
            // self.checkUserBehavior(userAddr: userAddr)

            //
            self.updateIncSupplyIndex(poolAddr: poolAddr)
            self.distributeSupplierInc(poolAddr: poolAddr, userAddr: userAddr)
        }

        pub fun redeemAllowed(poolAddr: Address, userAddr: Address, redeemOverlyingAmount: UFix64) {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknow pool."
            }
            // 检查该用户是否行为异常
            self.checkUserBehavior(userAddr: userAddr)
            
            // TODO 节省gas 如果用户无borrow, 不用流动性检测

            let liqRes = self.getHypotheticalAccountLiquidityInternal(
                userAddr: userAddr,
                targetPoolAddr: poolAddr,
                testRedeemAmount: redeemOverlyingAmount,
                testBorrowAmount: 0.0
            )
            assert(liqRes[1] == 0.0, message: "Insufficient liquidity.")

            //
            self.updateIncSupplyIndex(poolAddr: poolAddr)
            self.distributeSupplierInc(poolAddr: poolAddr, userAddr: userAddr)
        }

        pub fun borrowAllowed(poolAddr: Address, userAddr: Address, borrowAmount: UFix64) {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknow pool."
            }

            // 检查该用户是否行为异常
            self.checkUserBehavior(userAddr: userAddr)

            let liqRes = self.getHypotheticalAccountLiquidityInternal(
                userAddr: userAddr,
                targetPoolAddr: poolAddr,
                testRedeemAmount: 0.0,
                testBorrowAmount: borrowAmount
            )
            assert(liqRes[1] == 0.0, message: "Insufficient liquidity.")
            
            //
            let borrowIndex = self.poolCaps[poolAddr]!.borrow()!.queryBorrowIndex()
            self.updateCompBorrowIndex(poolAddr: poolAddr, borrowIndex: borrowIndex)
            self.distributeBorrowerComp(poolAddr: poolAddr, borrowerAddr: userAddr, borrowIndex: borrowIndex)
        }

        pub fun repayBorrowAllowed(poolAddr: Address, borrowerAddr: Address, repayUnderlyingVault: &FungibleToken.Vault) {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknow pool."
            }

            //
            let borrowIndex = self.poolCaps[poolAddr]!.borrow()!.queryBorrowIndex()
            self.updateCompBorrowIndex(poolAddr: poolAddr, borrowIndex: borrowIndex)
            self.distributeBorrowerComp(poolAddr: poolAddr, borrowerAddr: borrowerAddr, borrowIndex: borrowIndex)
        }

        pub fun seizeAllowed(poolAddr: Address, seizer: Address, borrower: Address, seizeOverlyingAmount: UFix64) {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknow pool."
            }
            

            //
            self.updateIncSupplyIndex(poolAddr: poolAddr)
            self.distributeSupplierInc(poolAddr: poolAddr, userAddr: borrower)
            self.distributeSupplierInc(poolAddr: poolAddr, userAddr: seizer)
        }

        // TODO 测试用例
        pub fun liquidate(
            borrower: Address,
            repayPoolAddr: Address,
            seizePoolAddr: Address,
            outOverlyingVaultCap: Capability<&{LedgerToken.PrivateCertificate}>,
            repayUnderlyingVault: @FungibleToken.Vault
        ) {
            pre {
                repayUnderlyingVault.balance > 0.0: "Need repay."
                outOverlyingVaultCap.check(): "Receiver vault lost."
                outOverlyingVaultCap.borrow()!.owner != nil: "Receiver vault must have owner."
                outOverlyingVaultCap.borrow()!.owner!.address != borrower: "Cannot liquidate self."
                self.poolCaps.containsKey(repayPoolAddr): "Unkonw pool."
                self.poolCaps.containsKey(seizePoolAddr): "Unkonw pool."
                self.poolCaps[repayPoolAddr]!.borrow()!.isOpen: "Repay pool is close."
                self.poolCaps[seizePoolAddr]!.borrow()!.isOpen: "Collateral pool is close."

            }
            let repayAmount = repayUnderlyingVault.balance
            // borrower liquidation check
            let liqRes = self.getHypotheticalAccountLiquidityInternal(
                userAddr: borrower,
                targetPoolAddr: 0x00,
                testRedeemAmount: 0.0,
                testBorrowAmount: 0.0
            )
            assert(liqRes[1] > 0.0, message: "No need to liquidate.")

            let repayPool      = self.poolCaps[repayPoolAddr]!.borrow()!
            let seizePool = self.poolCaps[seizePoolAddr]!.borrow()!

            assert(repayPool.queryComptrollerUuid() == seizePool.queryComptrollerUuid(), message: "Mismatch comptroller.")
            
            repayPool.accrueInterest()

            // borrowBalance 50% limit
            let borrowBalance = repayPool.queryBorrowBalanceSnapshot(userAddr: borrower)
            assert(borrowBalance * self.liquidateCloseFactor >= repayAmount, message: "Too much liquidation.")

            // repay borrow first
            repayPool.repayBorrow(repayUnderlyingVault: <-repayUnderlyingVault, borrowerAddr: borrower)

            // 计算应取走的CDToken
            let seizeAmount = self.liquidateCalculateSeizeTokens()

            // 取走collateral
            seizePool.seizeInternal(
                seizeOverlyingAmount: seizeAmount,
                borrowerAddr: borrower,
                outOverlyingVaultCap: outOverlyingVaultCap
            )

            // TODO event
        }

        pub fun liquidateBorrowAllowed() {

        }

        // TODO
        pub fun liquidateCalculateSeizeTokens(): UFix64 {
            // TODO 检测被清算address与被清算vault是否从属
            return 1.0
        }

        //
        pub fun getHypotheticalAccountLiquidityInternal(userAddr: Address, targetPoolAddr: Address, testRedeemAmount: UFix64, testBorrowAmount: UFix64): [UFix64] {
            pre {
                testRedeemAmount == 0.0 || testBorrowAmount == 0.0: "Liquidity test param error."
            }
            // 遍历每个用户的开户pool
            // TODO 这里需要优化gas
            var sumCollateral: UFix64 = 0.0
            var sumBorrowPlusEffects: UFix64 = 0.0

            for poolAddr in self.poolCaps.keys {
                let pool = self.poolCaps[poolAddr]!.borrow()!

                let overlyingBalance    = pool.queryOverlyingBalance(userAddr: userAddr)
                let borrowBalance       = pool.queryBorrowBalanceSnapshot(userAddr: userAddr)
                let exchangeRate        = pool.queryExchange()
                let collateralFactor    = pool.queryCollateralFactor()
                let underlyingType      = pool.underlyingType
                if overlyingBalance == 0.0 && borrowBalance == 0.0 {
                    continue
                }
                // TODO 预言机价格
                let oraclePrice         = 1.0
                assert(oraclePrice > 0.0, message: "Oracle price error.")
                let tokensToDenom = collateralFactor * exchangeRate * oraclePrice
                
                sumCollateral = tokensToDenom * overlyingBalance + sumCollateral
                sumBorrowPlusEffects = oraclePrice * borrowBalance + sumBorrowPlusEffects
                log("已有欠款 ".concat(pool.underlyingName).concat(borrowBalance.toString()))

                if targetPoolAddr == poolAddr {
                    sumBorrowPlusEffects = tokensToDenom * testRedeemAmount + sumBorrowPlusEffects
                    sumBorrowPlusEffects = oraclePrice * testBorrowAmount + sumBorrowPlusEffects
                }
            }
            log("检查用户 ".concat(userAddr.toString()).concat(" 的全部抵押物价值: ").concat(sumCollateral.toString()).concat(" 负债价值: ").concat(sumBorrowPlusEffects.toString()))
            if sumCollateral > sumBorrowPlusEffects {
                return [sumCollateral - sumBorrowPlusEffects, 0.0]
            } else {
                return [0.0, sumBorrowPlusEffects - sumCollateral]
            }
        }

        pub fun checkUserBehavior(userAddr: Address) {
            for poolAddr in self.poolCaps.keys {
                let pool = self.poolCaps[poolAddr]!.borrow()!
                assert(pool.checkUserVault(userAddr: userAddr), message: "User has misbehaviror, waiting for audit.")
            }
        }

        // TODO
        priv fun updateIncSupplyIndex(poolAddr: Address) {
        }
        priv fun distributeSupplierInc(poolAddr: Address, userAddr: Address) {

        }
        priv fun updateCompBorrowIndex(poolAddr: Address, borrowIndex: UFix64) {

        }
        priv fun distributeBorrowerComp(poolAddr: Address, borrowerAddr: Address, borrowIndex: UFix64) {

        }

        pub fun queryPoolInfo(poolAddr: Address): IncQueryInterface.PoolInfo {
            pre {
                self.poolCaps.containsKey(poolAddr): "Unknow pool address."
                self.poolCaps[poolAddr]!.check(): "Pool cap is invalid."
            }
            let pool = self.poolCaps[poolAddr]!.borrow()!
            // TODO total supply
            let info = IncQueryInterface.PoolInfo(
                overlyingName: pool.overlyingName,
                underlyingName: pool.underlyingName,
                poolAddr: poolAddr,
                isOpen: pool.isOpen,
                canDeposit: pool.canDeposit,
                canWithdra: pool.canRedeem,
                canBorrow: pool.canBorrow,
                totalSupply: 0.0,
                totalBorrow: 0.0,
                totalSupplyUSD: 0.0,
                totalBorrowUSD: 0.0,
                apySupply: 0.0,
                apyborrow: 0.0,
                oraclePriceUSD: 1.0
            )
            return info
        }
        pub fun queryAllPoolInfos(): [IncQueryInterface.PoolInfo] {
            var res: [IncQueryInterface.PoolInfo] = []
            for poolAddr in self.poolCaps.keys {
                res.append(
                    self.queryPoolInfo(poolAddr: poolAddr)
                )
            }
            return res
        }
        pub fun queryUniverseBalance(): IncQueryInterface.UniverseBalance {
            return IncQueryInterface.UniverseBalance(
                totalSupplyUSD: 0.0,
                totalBorrowUSD: 0.0
            )
        }
        pub fun queryUserBalance(userAddr: Address): IncQueryInterface.UserBalance {
            return IncQueryInterface.UserBalance(
                totalSupplyUSD: 0.0,
                totalBorrowUSD: 0.0,
                apy: 0.0,
                borrowLimit: 0.0,
                borrowLimitUsed: 0.0
            )
        }
        pub fun queryUserPoolSupplyInfo(userAddr: Address): [IncQueryInterface.UserPoolInfo] {

            return []
        }
        pub fun queryUserPoolBorrowInfo(userAddr: Address): [IncQueryInterface.UserPoolInfo] {
            
            return []
        }

    }


    pub let Comptroller_StoragePath: StoragePath
    pub let Comptroller_PublicPath: PublicPath
    pub let Comptroller_PrivatePath: PrivatePath

    init() {
        self.Comptroller_StoragePath = /storage/comptroller
        self.Comptroller_PublicPath = /public/comptroller
        self.Comptroller_PrivatePath = /private/comptroller

        let comptroller <- create Comptroller()
        self.account.save(<-comptroller, to: self.Comptroller_StoragePath)
        self.account.link   <&{IncComptrollerInterface.ComptrollerPublic}>  (self.Comptroller_PublicPath,   target: self.Comptroller_StoragePath)
        // TODO 此处暂时将整个Comptroller作为接口暴露
        self.account.link   <&Comptroller>          (self.Comptroller_PrivatePath,  target: self.Comptroller_StoragePath)

    }
    
}