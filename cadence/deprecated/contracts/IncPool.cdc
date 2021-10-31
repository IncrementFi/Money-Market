import FungibleToken from "./FungibleToken.cdc"
import LedgerToken from "./LedgerToken.cdc"
import IncComptroller from "./IncComptroller.cdc"
import IncPoolInterface from "./IncPoolInterface.cdc"

pub contract IncPool: IncPoolInterface {

    pub let PoolPath_Storage: StoragePath
    pub let PoolPath_Public: PublicPath
    pub let PoolPath_Private: PrivatePath
    pub let PoolSetUpPath_Public: PublicPath
    pub let PoolTokenInterfacePath_Private: PrivatePath

    access(contract) var totalSupply: UFix64
    access(contract) var totalCash: UFix64
    access(contract) var totalBorrows: UFix64
    access(contract) var totalReserves: UFix64
    access(contract) var accrualBlockNumber: UInt64
    access(contract) var borrowIndex: UFix64
    access(contract) let initialExchangeRate: UFix64
    access(contract) var protocalSeizeShare: UFix64 // 清算中扣除的
    access(contract) var reserveFactor: UFix64 // borrow利息中扣除的
    access(contract) var collateralFactor: UFix64 // 抵押率
    access(contract) var borrowUpperLimit: UFix64 // borrow上限
    //
    access(contract) let accountBorrows: {Address: BorrowSnapshot}
    // TODO 删除用户记录
    // 不允许同一用户存在多个overlying token vault, 用户如果更换, 将取消之前的绑定, 可能引发清算
    access(contract) let accountVaults: {Address: VaultSnapshot}
    
    //
    //access(contract) let overlyingType:  Type
    //access(contract) let underlyingType: Type
    access(contract) let overlyingName:  String
    access(contract) let underlyingName: String
    
    access(contract) var isOpen: Bool
    access(contract) var canDeposit: Bool
    access(contract) var canRedeem: Bool
    access(contract) var canBorrow: Bool
    
    // 基本组件全部nested强连接，使用cap不稳定，万一不小心cap被覆盖
    access(contract) let overlyingMinter: @LedgerToken.Minter
    access(contract) let ledgerManager: @LedgerToken.LedgerManager
    //
    access(contract) let underlyingVault: @FungibleToken.Vault
    //
    access(contract) var comptrollerCap: Capability<&IncComptroller.Comptroller>?
    
    pub struct BorrowSnapshot {
        pub var principal: UFix64
        pub var interestIndex: UFix64
        init(principal: UFix64, interestIndex: UFix64) {
            self.principal = principal
            self.interestIndex = interestIndex
        }
        access(contract) fun update(principal: UFix64, interestIndex: UFix64) {
            self.principal = principal
            self.interestIndex = interestIndex
        }
    }
    
    pub struct VaultSnapshot {
        pub var uuid: UInt64
        pub var receiverCap: Capability<&{LedgerToken.IdentityReceiver}>
        pub var ifCollateral: Bool
        init(vaultId: UInt64, receiverCap: Capability<&{LedgerToken.IdentityReceiver}>) {
            self.uuid = vaultId
            self.receiverCap = receiverCap
            self.ifCollateral = false
        }
        access(contract) fun setReceiverCap(receiverCap: Capability<&{LedgerToken.IdentityReceiver}>) { self.receiverCap = receiverCap }
        access(contract) fun openCollateral(_ on: Bool) { self.ifCollateral = on }
    }

    access(contract) fun borrowBalanceSnapshot(address: Address): UFix64 {
        var borrowSnapshot = self.accountBorrows.containsKey(address)? self.accountBorrows[address]! : BorrowSnapshot(principal:0.0, interestIndex:self.borrowIndex)
        if borrowSnapshot.principal == 0.0 {
            return 0.0
        }
        let currentAcc = borrowSnapshot.principal * self.borrowIndex
        let deltAcc = currentAcc / borrowSnapshot.interestIndex
        return deltAcc
    }

    access(contract) fun exchangeRateStoredInternal(): UFix64 {
        log("total supply".concat(self.totalSupply.toString()))
        log("total cash".concat(self.totalCash.toString()))
        log("total borrow".concat(self.totalBorrows.toString()))
        log("total reserve".concat(self.totalReserves.toString()))
        

        if self.totalSupply == 0.0 {
            return self.initialExchangeRate
        } else {
            return (self.totalCash + self.totalBorrows - self.totalReserves) / self.totalSupply
        }
    }

    access(contract) fun accrueInterest() {
        let currentBlockNumber = getCurrentBlock().height
        let accrualBlockNumberPrior = self.accrualBlockNumber
        if currentBlockNumber == accrualBlockNumberPrior { return }
        let cashPrior        = self.totalCash
        let borrowPrior      = self.totalBorrows
        let reservesPrior    = self.totalReserves
        let borrowIndexPrior = self.borrowIndex

        // TODO interestRateModel
        let borrowRate = 0.01
        let blockDelta = currentBlockNumber - accrualBlockNumberPrior
        let simpleInterestFactor = borrowRate * UFix64(blockDelta)
        let interestAccumulated = simpleInterestFactor * borrowPrior
        let totalBorrowsNew = interestAccumulated + borrowPrior
        // TODO 这部分利息产生的reserve 现在就计算到total里了?
        let totalReservesNew = self.reserveFactor * interestAccumulated + reservesPrior
        let borrowIndexNew = simpleInterestFactor * borrowIndexPrior + borrowIndexPrior
        
        //
        self.accrualBlockNumber = currentBlockNumber
        self.borrowIndex = borrowIndexNew
        self.totalBorrows = totalBorrowsNew
        self.totalReserves = totalReservesNew
        
        // TODO Event
    }

    access(contract) fun exchangeUnderlyingToOverlying(_ n:UFix64): UFix64 {
        return n / self.exchangeRateStoredInternal()
    }

    access(contract) fun exchangeOverlyingToUnderlying(_ n:UFix64): UFix64 {
        return n * self.exchangeRateStoredInternal()
    }

    access(contract) fun updateAccountBorrow(userAddr: Address, principal: UFix64, interestIndex: UFix64) {
        if self.accountBorrows.containsKey(userAddr) == false {
            self.accountBorrows[userAddr] = BorrowSnapshot(principal:principal, interestIndex:interestIndex)
        } else {
            self.accountBorrows[userAddr]!.update(principal: principal, interestIndex: interestIndex)
        } 
    }

    // TODO !!!!!!!!! 这里没有考虑进度问题:   1.00000000 -> 0.99999999  后续要有利于于系统
    // TODO 请检查: 不同于以太坊，pool会维持一份数据, 货币协议里也会维持一份, 在只有一个minter的情况下, 应该保持一致
    access(contract) fun addTotalSupply(_ n:UFix64) { self.totalSupply = self.totalSupply + n }
    access(contract) fun subTotalSupply(_ n:UFix64) { self.totalSupply = self.totalSupply - n }
    access(contract) fun addTotalCash(_ n:UFix64) { self.totalCash = self.totalCash + n }
    access(contract) fun subTotalCash(_ n:UFix64) { self.totalCash = self.totalCash - n }
    access(contract) fun addTotalBorrow(_ n:UFix64) { self.totalBorrows = self.totalBorrows + n }
    access(contract) fun subTotalBorrow(_ n:UFix64) { self.totalBorrows = self.totalBorrows - n }
    access(contract) fun addTotalReserves(_ n:UFix64) { self.totalReserves = self.totalReserves + n }
    access(contract) fun subTotalReserves(_ n:UFix64) { self.totalReserves = self.totalReserves - n }


    pub resource interface PoolSetup {
        pub fun setComptroller(comptrollerCap: Capability<&IncComptroller.Comptroller>)
    }



    pub resource PoolBehaviour: IncPoolInterface.PoolPublic, IncPoolInterface.PoolPrivate, PoolSetup, IncPoolInterface.PoolTokenInterface {
        
        // 存款, 以明确认证vault的方式, 如果vault有一丝异常直接失败
        pub fun depositExplicitly(inUnderlyingVault: @FungibleToken.Vault, outOverlyingVaultCap: Capability<&{LedgerToken.IdentityReceiver}>) {
            let userAddr = outOverlyingVaultCap.borrow()!.owner!.address
            // 此次vault是否与服务器记录一致
            let newVaultId = outOverlyingVaultCap.borrow()!.uuid
            if IncPool.accountVaults.containsKey(userAddr) {
                assert(IncPool.accountVaults[userAddr]!.receiverCap.check(), message: "Snapshot overlying vault lost, waiting for auditing.")
                let snapshotVaultId = IncPool.accountVaults[userAddr]!.uuid
                // cap指向的vualt id 与 缓存的id不符, 私下更换cap的指针
                assert(IncPool.accountVaults[userAddr]!.receiverCap.borrow()!.uuid == snapshotVaultId, message: "Snapshot vault's id != snapshot id")
                //
                assert(newVaultId == snapshotVaultId, message: "New vault id != snapshot vault id")
            }

            self.deposit(inUnderlyingVault: <-inUnderlyingVault, outOverlyingVaultCap: outOverlyingVaultCap)
        }

        // 强行存款, vault无意或者恶意的被覆盖, 可能会引发清算
        // 客户端需要检测vault, 帮助正常用户
        pub fun deposit(inUnderlyingVault: @FungibleToken.Vault, outOverlyingVaultCap: Capability<&{LedgerToken.IdentityReceiver}>) {
            pre {
                inUnderlyingVault.balance > 0.0: "Deposit nothing."
                outOverlyingVaultCap.check(): "Invalid overlying receiver vault cap."
                outOverlyingVaultCap.borrow()!.owner != nil: "Receiver vault must have owner."
                IncPool.comptrollerCap != nil && IncPool.comptrollerCap!.check(): "Should register comptroller."
                IncPool.isOpen == true: "Pool closed."
                IncPool.canDeposit == true: "Deposit is pause."
            }
            // TODO 如果用户恶意移走本地的overlyingVault并试图变现

            // 必须含有addr
            let userAddr = outOverlyingVaultCap.borrow()!.owner!.address
            if IncPool.accountVaults.containsKey(userAddr) {
                assert(IncPool.accountVaults[userAddr]!.receiverCap.check(), message: "Snapshot overlying vault lost, waiting for auditing.")
            }
            //
            IncPool.accrueInterest()
            // deposit comptroller
            IncPool.comptrollerCap!.borrow()!.minterAllowed(poolAddr: self.owner!.address, inUnderlyingVault: &inUnderlyingVault as &FungibleToken.Vault, outOverlyingVaultCap: outOverlyingVaultCap)

            let amount_underlying = inUnderlyingVault.balance

            // transfer underlying in
            IncPool.underlyingVault.deposit(from: <-inUnderlyingVault)
            //
            let amount_overlying = IncPool.exchangeUnderlyingToOverlying(amount_underlying)
            let tmpOverlyingVault <- IncPool.overlyingMinter.mintTokens(amount: amount_overlying)
            // transfer overlying out
            outOverlyingVaultCap.borrow()!.deposit(from: <-tmpOverlyingVault)
            
            let newVaultId = outOverlyingVaultCap.borrow()!.uuid
            // 如果是首次存款, 本地的ctoken收款vault也应该是干净的
            // 保存user -> vault关系, 并锁定vault的最初始拥有者
            if IncPool.accountVaults.containsKey(userAddr) == false {
                assert(outOverlyingVaultCap.borrow()!.getInfo().originalOwner == nil, message: "Must use a clean CDToken vault.")
                IncPool.ledgerManager.setVaultOriginalOwner(uuid: newVaultId, owner: userAddr)
                IncPool.accountVaults[userAddr] = VaultSnapshot(vaultId: newVaultId, receiverCap: outOverlyingVaultCap)
            } else {
                // 一旦ctoken vault绑定之后, 不可以随意更换
                let snapshotVaultId = IncPool.accountVaults[userAddr]!.uuid
                assert(newVaultId == snapshotVaultId, message: "Deposit receiver vault must be the orignial one.")
            }
            // TODO 用户可以申请删除本地的vault绑定

            // update data
            IncPool.addTotalSupply(amount_overlying)
            IncPool.addTotalCash(amount_underlying)
            // TODO event
        }
        
        pub fun redeemExplicitly(redeemOverlyingAmount: UFix64, identityCap: Capability<&{LedgerToken.IdentityReceiver}>, outUnderlyingVaultCap: Capability<&{FungibleToken.Receiver}>) {
            pre {
                IncPool.comptrollerCap != nil && IncPool.comptrollerCap!.check(): "Should register comptroller."
                redeemOverlyingAmount > 0.0: "Redeem amount = 0."
                outUnderlyingVaultCap.check(): "Invalid overlying receiver vault cap."
                outUnderlyingVaultCap.borrow()!.owner != nil: "Receiver vault must have owner."
                identityCap.check(): "Must have user certificate."
                identityCap.borrow()!.owner != nil: "Must have user certificate."
                identityCap.borrow()!.owner!.address == outUnderlyingVaultCap.borrow()!.owner!.address: "User of certificate and receiver must be the same."
                IncPool.isOpen == true: "Pool closed."
                IncPool.canRedeem == true: "Redeem is pause."
            }
            let userAddr = identityCap.borrow()!.owner!.address
            //
            IncPool.accrueInterest()

            // 取出全部
            var _redeemOverlyingAmount = redeemOverlyingAmount
            let snapshotVaultId = IncPool.accountVaults[userAddr]!.uuid
            if redeemOverlyingAmount == UFix64.max {
                _redeemOverlyingAmount = IncPool.ledgerManager.queryBalance(vaultId: snapshotVaultId)
            }

            // redeem comptroller
            IncPool.comptrollerCap!.borrow()!.redeemAllowed(poolAddr: self.owner!.address, userAddr: userAddr, redeemOverlyingAmount: _redeemOverlyingAmount)

            // 销毁用户ctoken
            let tmpVault <- IncPool.ledgerManager.withdraw(amount: _redeemOverlyingAmount, fromUuid: snapshotVaultId)
            destroy tmpVault

            let redeemUnderlyingAmount = IncPool.exchangeOverlyingToUnderlying(_redeemOverlyingAmount)
            // 取usd给用户
            let underlyingVault <- IncPool.underlyingVault.withdraw(amount: redeemUnderlyingAmount)
            outUnderlyingVaultCap.borrow()!.deposit(from: <-underlyingVault)

            // TODO update用户本地vault
            IncPool.accountVaults[userAddr]!.receiverCap.borrow()!.updateBalance()

            // updata data
            IncPool.subTotalSupply(_redeemOverlyingAmount)
            IncPool.subTotalCash(redeemUnderlyingAmount)
        }

        // 这是一种匿名redeem模式, 废弃
        // TODO 如果用户想要赎回固定数量的FUSD, 需要客户端计算传入的ctoken量
        pub fun redeem(inOverlyingVault: @FungibleToken.Vault, outUnderlyingVaultCap: Capability<&{FungibleToken.Receiver}>) {
            pre {
                IncPool.comptrollerCap != nil && IncPool.comptrollerCap!.check(): "Should register comptroller."
                inOverlyingVault.balance > 0.0: "Redeem amount = 0."
                outUnderlyingVaultCap.check(): "Invalid overlying receiver vault cap."
                outUnderlyingVaultCap.borrow()!.owner != nil: "Receiver vault must have owner."
                IncPool.isOpen == true: "Pool closed."
                IncPool.canRedeem == true: "Redeem is pause."
            }
            // TODO 如果此inOverlyingVault是一个用户的整个vault, 需要检测服务器端的cap是否正常, 防止用户恶意转移vault并套现

            let userAddr = outUnderlyingVaultCap.borrow()!.owner!.address
            //
            IncPool.accrueInterest()
            //
            // redeem comptroller
            // IncPool.comptrollerCap!.borrow()!.redeemAllowed(poolAddr: self.owner!.address, inOverlyingVault: &inOverlyingVault as &FungibleToken.Vault, outUnderlyingVaultCap: outUnderlyingVaultCap)

            let amount_overlying = inOverlyingVault.balance
            let amount_underlying = IncPool.exchangeOverlyingToUnderlying(amount_overlying)
            //
            let underlyingVault <- IncPool.underlyingVault.withdraw(amount: amount_underlying)
            outUnderlyingVaultCap.borrow()!.deposit(from: <-underlyingVault)

            // updata data
            IncPool.subTotalSupply(amount_overlying)
            IncPool.subTotalCash(amount_underlying)
            //
            destroy inOverlyingVault
            // TODO event
        }

        // 用户需要上传private抵押物cap证明来做身份验证
        pub fun borrow(amountUnderlyingBorrow: UFix64, identityCaps: [Capability<&{LedgerToken.IdentityReceiver}>], outUnderlyingVaultCap: Capability<&{FungibleToken.Receiver}>) {
            pre {
                IncPool.totalCash >= amountUnderlyingBorrow: "No enough pool cash."
                outUnderlyingVaultCap.check() && outUnderlyingVaultCap.borrow()!.owner != nil: "Receiver vault must have owner."
                IncPool.comptrollerCap != nil && IncPool.comptrollerCap!.check(): "Should register comptroller."
                identityCaps.length > 0: "Must upload at least one collateral certification."
                IncPool.isOpen: "Pool closed."
                IncPool.canBorrow: "Borrow is pause."
            }
            
            // 这里强制约束: 所有的抵押vaults和收款vaults必须由owner, 且为同一address, 该address作为用户判定
            let userAddr = outUnderlyingVaultCap.borrow()!.owner!.address
            for cap in identityCaps {
                assert(cap.borrow()!.owner!.address == userAddr, message: "Collaterals should have the same owner")
            }
            //
            IncPool.accrueInterest()

            // 如果用户为开启抵押, 自动打开
            IncPool.accountVaults[userAddr]!.openCollateral(true)
            
            // 借钱能力审计
            IncPool.comptrollerCap!.borrow()!.borrowAllowed(poolAddr: self.owner!.address, userAddr: userAddr, borrowAmount: amountUnderlyingBorrow)

            // 当前pool里的借款+生息
            let curBorrow = IncPool.borrowBalanceSnapshot(address: userAddr)
            let newBorrow = curBorrow + amountUnderlyingBorrow

            // 借款上限
            // TODO 测试用例
            if IncPool.borrowUpperLimit > 0.0 {
                assert(IncPool.borrowUpperLimit > newBorrow, message: "Pool borrow upper limit reached.")
            }

            // 借出:
            let outUnderlyingVault <- IncPool.underlyingVault.withdraw(amount: amountUnderlyingBorrow)
            outUnderlyingVaultCap.borrow()!.deposit(from: <-outUnderlyingVault)
            // update data
            IncPool.subTotalCash(amountUnderlyingBorrow)
            IncPool.addTotalBorrow(amountUnderlyingBorrow)
            IncPool.updateAccountBorrow(userAddr: userAddr, principal: newBorrow, interestIndex: IncPool.borrowIndex)

            // TODO event
        }

        //
        pub fun repayBorrow(repayUnderlyingVault: @FungibleToken.Vault, borrowerAddr: Address) {
            pre {
                repayUnderlyingVault.balance > 0.0: "Empty repay vault."
                IncPool.isOpen == true: "Pool closed."
            }
            // 偿还审计
            IncPool.comptrollerCap!.borrow()!.repayBorrowAllowed(poolAddr: self.owner!.address, borrowerAddr: borrowerAddr, repayUnderlyingVault: &repayUnderlyingVault as &FungibleToken.Vault)
            // 
            IncPool.accrueInterest()
            //
            let repayUnderlyingAmount = repayUnderlyingVault.balance
            // 当前借款+生息
            let curBorrows = IncPool.borrowBalanceSnapshot(address: borrowerAddr)
            // TODO 这里可能存在还款剩余零头的问题，UI获取的欠款需要在发送TX时刷新
            // TODO 全部还清的UI设置

            assert(repayUnderlyingAmount <= curBorrows, message: "Wasted repay.")
            // transfer in
            IncPool.underlyingVault.deposit(from: <-repayUnderlyingVault)
            // update data
            let newBorrow = curBorrows - repayUnderlyingAmount
            IncPool.updateAccountBorrow(userAddr: borrowerAddr, principal: newBorrow, interestIndex: IncPool.borrowIndex)
            IncPool.subTotalBorrow(repayUnderlyingAmount)

            // TODO event
        }

        pub fun seizeInternal(seizeOverlyingAmount: UFix64, borrowerAddr: Address, outOverlyingVaultCap: Capability<&{LedgerToken.IdentityReceiver}>) {
            pre {
                IncPool.isOpen == true: "Pool closed."
                IncPool.accountVaults.containsKey(borrowerAddr): "No collateral."
            }
            // 检查ctoken接受cap必须是原始的那个
            self.checkUserUploadVaultIdentityCap(identity: outOverlyingVaultCap)

            let seizer = outOverlyingVaultCap.borrow()!.owner!.address
            // comptroller审计
            IncPool.comptrollerCap!.borrow()!.seizeAllowed(
                poolAddr: self.owner!.address,
                seizer: seizer,
                borrower: borrowerAddr,
                seizeOverlyingAmount: seizeOverlyingAmount
            )

            let collateralVaultId: UInt64 = IncPool.accountVaults[borrowerAddr]!.uuid

            // 协议拿走2.8%
            let protocalSeizeOverlying = seizeOverlyingAmount * IncPool.protocalSeizeShare
            let liquatorSeizeOverlying = seizeOverlyingAmount - protocalSeizeOverlying
            let protocalSeizeUnderlying = IncPool.exchangeOverlyingToUnderlying(protocalSeizeOverlying)
            // 获取借款人的vault
            // 这里需要已经由comptroller检测过uuid 与 address
            
            // 中心账本withdraw 清算人应获取的
            let liquatorSeizeVault <- IncPool.ledgerManager.withdraw(amount: liquatorSeizeOverlying, fromUuid: collateralVaultId)
            outOverlyingVaultCap.borrow()!.deposit(from: <-liquatorSeizeVault)

            // 协议拿走的
            let protocalSeizeVault <- IncPool.ledgerManager.withdraw(amount: protocalSeizeOverlying, fromUuid: collateralVaultId)
            destroy protocalSeizeVault

            // 被清算的vault的cap正常, 调用update
            IncPool.accountVaults[borrowerAddr]!.receiverCap.borrow()!.updateBalance()

            // update data
            IncPool.addTotalReserves(protocalSeizeUnderlying)
            // TODO 注意: 这里会导致pool的supply和token里的supply不一致, 需要check
            IncPool.subTotalSupply(protocalSeizeOverlying)

            // TODO event
        }
        

        pub fun checkUserLiquidity(userAddr: Address, testRedeemAmount: UFix64, testBorrowAmount: UFix64): [UFix64] {
            let checkRes = IncPool.comptrollerCap!.borrow()!.getHypotheticalAccountLiquidityInternal(
                userAddr: userAddr,
                targetPoolAddr: self.owner!.address,
                testRedeemAmount: testRedeemAmount,
                testBorrowAmount: testBorrowAmount
            )
            return checkRes
        }

        // 查询当前借款+利息
        pub fun queryBorrowBalanceSnapshot(userAddr: Address): UFix64 { return IncPool.borrowBalanceSnapshot(address: userAddr) }
        pub fun queryBorrowBalanceRealtime(userAddr: Address): UFix64 {
            IncPool.accrueInterest()
            return self.queryBorrowBalanceSnapshot(userAddr: userAddr)
        }
        // 用户ctoken查询
        pub fun queryOverlyingBalance(userAddr: Address): UFix64 {
            pre {
                // 用户恶意失效了cap, 或者冒充了其他vault
                self.checkUserLocalVaultIdentityCap(userAddr: userAddr): "Misbehavior user, waiting for audit."
            }
            // 一个用户在一个pool只会存在一个vault
            if IncPool.accountVaults.containsKey(userAddr) == false {
                return 0.0
            }
            
            let overlyingVaultId = IncPool.accountVaults[userAddr]!.uuid
            let overlyingBalance = IncPool.ledgerManager.queryBalance(vaultId: overlyingVaultId)
            return overlyingBalance
        }
        pub fun queryExchange(): UFix64 { return IncPool.exchangeRateStoredInternal() }
        pub fun queryCollateralFactor(): UFix64 { return IncPool.collateralFactor }
        pub fun queryBorrowIndex(): UFix64 { return IncPool.borrowIndex }
        pub fun queryComptrollerUuid(): UInt64 { return IncPool.comptrollerCap!.borrow()!.uuid }
        pub fun queryOpenCollateral(userAddr: Address): Bool {
            pre {
                IncPool.accountVaults.containsKey(userAddr): "Unknow user."
            }
            return IncPool.accountVaults[userAddr]!.ifCollateral
        }


        pub fun openPool(_ open: Bool) { IncPool.isOpen = open }
        // 是否开启作为抵押物
        pub fun openCollateral(open: Bool, identityCap: Capability<&{LedgerToken.IdentityReceiver}>) {
            pre {
                IncPool.isOpen: "Pool is close."
            }
            self.checkUserUploadVaultIdentityCap(identity: identityCap)
            let userAddr = identityCap.borrow()!.owner!.address
            assert(IncPool.accountVaults[userAddr]!.ifCollateral != open, message: "Parameter error.")
            if open == false {
                // TODO 测试用例
                let overlyingBalance = self.queryOverlyingBalance(userAddr: userAddr)
                let borrowBalance = self.queryBorrowBalanceRealtime(userAddr: userAddr)
                // 有欠款不让退市
                assert(borrowBalance == 0.0, message: "Close collateral reject, still have borrows.")
                // 如果是关闭, 需要做流动性检测
                self.checkUserLiquidity(userAddr: userAddr, testRedeemAmount: overlyingBalance, testBorrowAmount: 0.0)
            }
            IncPool.accountVaults[userAddr]!.openCollateral(open)
        }

        // TODO 此处使用类型来确定来者的正确性, 但如果Comptroller具有扩展性, 要如何判断来人呢?
        pub fun setComptroller(comptrollerCap: Capability<&IncComptroller.Comptroller>) {
            // TODO 有一种比较triky的方式是: 要求来者的cap地址必须是固定的.

            // TODO 这里暂时直接传递comptroller, 之后需要封装到一个类似minter proxy的子资源
            if IncPool.comptrollerCap == nil {
                IncPool.comptrollerCap = comptrollerCap
            }
        }

        // 检查用户当前的抵押vault cap是否正常, cap是否失效, 本地vault是否被移走
        pub fun checkUserLocalVaultIdentityCap(userAddr: Address): Bool {
            if IncPool.accountVaults.containsKey(userAddr) == false { return true }
            let vaultId = IncPool.accountVaults[userAddr]!.uuid
            let receiverCap = IncPool.accountVaults[userAddr]!.receiverCap
            if receiverCap.check() == false { return false }
            // TODO 这一步是否多余? check能检测borrow吗
            if receiverCap.borrow() == nil { return false }
            if receiverCap.borrow()!.uuid != vaultId { return false }

            return true
        }

        // 检查用户上传的身份认证cap是否正常
        pub fun checkUserUploadVaultIdentityCap(identity: Capability<&{LedgerToken.IdentityReceiver}>) {
            pre {
                identity.check(): "Lost identity cap."
                identity.borrow()!.owner != nil: "Identity cap must have the owner."
            }
            let userAddr = identity.borrow()!.owner!.address
            assert(IncPool.accountVaults.containsKey(userAddr) == true, message: "Unknow user.")
            assert(self.checkUserLocalVaultIdentityCap(userAddr: userAddr), message: "The original identity cap is abnormal.")
            assert(IncPool.accountVaults[userAddr]!.uuid == identity.borrow()!.uuid, message: "Upload identity must be the original one.")
        }

        pub fun accrueInterestExternal() { IncPool.accrueInterest() }

        //pub fun overlyingType(): Type { return IncPool.overlyingType }
        //pub fun underlyingType(): Type { return IncPool.underlyingType }
        pub fun overlyingName(): String { return IncPool.overlyingName }
        pub fun underlyingName(): String { return IncPool.underlyingName }
        pub fun canBorrow(): Bool { return IncPool.canBorrow }
        pub fun canRedeem(): Bool { return IncPool.canRedeem }
        pub fun canDeposit(): Bool { return IncPool.canDeposit }
        pub fun isOpen(): Bool { return IncPool.isOpen }
    }

    init(
        //overlyingType:          Type,
        overlyingName:          String,
        //underlyingType:         Type,
        underlyingName:         String
    ) {
        self.PoolPath_Storage = /storage/pool
        self.PoolPath_Public = /public/pool
        self.PoolSetUpPath_Public = /public/poolsetup
        self.PoolPath_Private = /private/pool
        self.PoolTokenInterfacePath_Private = /private/pooltokeninterface

        self.totalSupply = 0.0
        self.totalCash = 0.0
        self.totalBorrows = 0.0
        self.totalReserves = 0.0
        

        self.accrualBlockNumber = getCurrentBlock().height
        // TODO 这些参数的初始化
        // TODO 调整参数的外界接口，投票
        self.initialExchangeRate = 1.0
        self.borrowIndex = 1.0

        self.reserveFactor = 0.01
        self.protocalSeizeShare = 0.028
        self.collateralFactor = 0.75
        self.borrowUpperLimit = 0.0

        self.accountBorrows = {}
        self.accountVaults  = {}

        //
        self.overlyingMinter <- self.account.load<@LedgerToken.Minter>(from: /storage/overlyingMinter) ?? panic("Lost local overlying minter.")
        //
        self.underlyingVault <- self.account.load<@FungibleToken.Vault>(from: /storage/underlyingVault) ?? panic("Lost local overlying vault.")
        //
        self.ledgerManager <- self.account.load<@LedgerToken.LedgerManager>(from: /storage/ledgerManager) ?? panic("Lost local ledger manager.")
        //
        self.account.save(<- create PoolBehaviour(), to: self.PoolPath_Storage)

        //
        self.account.link <&{IncPoolInterface.PoolPublic}>          (IncPool.PoolPath_Public,                target: IncPool.PoolPath_Storage)
        self.account.link <&{IncPoolInterface.PoolPrivate}>         (IncPool.PoolPath_Private,               target: IncPool.PoolPath_Storage)
        self.account.link <&{IncPool.PoolSetup}>                    (IncPool.PoolSetUpPath_Public,           target: IncPool.PoolPath_Storage)
        self.account.link <&{IncPoolInterface.PoolTokenInterface}>  (IncPool.PoolTokenInterfacePath_Private, target: IncPool.PoolPath_Storage)
        

        // TODO
        //self.overlyingType          = overlyingType
        self.overlyingName          = overlyingName
        //self.underlyingType         = underlyingType
        self.underlyingName         = underlyingName
        self.comptrollerCap         = nil

        
        self.canDeposit             = true
        self.canRedeem              = true
        self.canBorrow              = true
        self.isOpen = false
    }
}