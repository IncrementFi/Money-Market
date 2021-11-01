import FungibleToken from "./FungibleToken.cdc"
import Interfaces from "./Interfaces.cdc"
import TwoSegmentsInterestRateModel from "./TwoSegmentsInterestRateModel.cdc"
import ComptrollerV1 from "./ComptrollerV1.cdc"
import Config from "./Config.cdc"

pub contract LendingPool {
    pub let PoolAdminStoragePath: StoragePath
    pub let UnderlyingAssetVaultStoragePath: StoragePath
    pub let PoolPublicStoragePath: StoragePath

    pub enum Error: UInt8 {
        pub case NO_ERROR
        pub case CURRENT_INTEREST_RATE_MODEL_NULL
        pub case SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED
        pub case SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED
        pub case SET_RESERVE_FACTOR_OUT_OF_RANGE
        pub case SET_POOL_SEIZE_SHARE_OUT_OF_RANGE
    }

    // Account address the pool is deployed to, i.e. the pool 'contract address'
    pub let poolAddress: Address
    // Initial exchange rate (when LendingPool.totalSupply == 0) between the virtual lpToken and pool underlying token
    pub let initialExchangeRate: UFix64
    // Block number that interest was last accrued at
    pub var accrualBlockNumber: UInt64
    // Accumulator of the total earned interest rate since the opening of the market
    pub var borrowIndex: UFix64
    // Total amount of outstanding borrows of the underlying in this market
    pub var totalBorrows: UFix64
    // Total amount of reserves of the underlying held in this market
    pub var totalReserves: UFix64
    // Total number of virtual lpTokens
    pub var totalSupply: UFix64
    // Fraction of generated interest added to protocol reserves.
    // Must be in [0.0, 1.0]
    pub var reserveFactor: UFix64
    // Share of seized collateral that is added to reserves when liquidation happenes, e.g. 0.028.
    // Must be in [0.0, 1.0]
    pub var poolSeizeShare: UFix64
    // { supplierAddress => # of virtual lpToken the supplier owns }
    access(contract) let accountLpTokens: {Address: UFix64}

    pub struct BorrowSnapshot {
        // Total balance (with accrued interest), after applying the most recent balance-change action
        pub var principal: UFix64
        // Global borrowIndex as of the most recent balance-change action
        pub var interestIndex: UFix64
    
        init(principal: UFix64, interestIndex: UFix64) {
            self.principal = principal
            self.interestIndex = interestIndex
        }
    }
    // { borrowerAddress => BorrowSnapshot }
    access(self) let accountBorrows: {Address: BorrowSnapshot}

    // Model used to calculate underlying asset's borrow interest rate
    pub var interestRateModelAddress: Address?
    pub var interestRateModelCap: Capability<&{Interfaces.InterestRateModelPublic}>?
    pub var comptrollerAddress: Address?
    pub var comptrollerCap: Capability<&{Interfaces.ComptrollerPublic}>?
    access(self) let underlyingAssetType: Type
    // Save underlying asset deposited into this pool
    access(self) let underlyingVault: @FungibleToken.Vault

    // TokensInitialized
    // The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)
    // Event emitted when there's a difference between contract-based data and vault-based data
    pub event TokensDiff(faultVaultId: UInt64, vaultData: UFix64, contractData: UFix64, owner: Address?)
    // Event emitted when interest is accrued
    pub event AccrueInterest(_ cashPrior: UFix64, _ interestAccumulated: UFix64, _ borrowIndexNew: UFix64, _ totalBorrowsNew: UFix64)
    // Event emitted when underlying asset is deposited into pool
    pub event Supply(suppliedUnderlyingAmount: UFix64, mintedLpTokenAmount: UFix64)
    // Event emitted when virtual lpToken is burnt and redeemed for underlying asset
    pub event Redeem(redeemer: Address, lpTokenToRedeem: UFix64, redeemedUnderlyingAmount: UFix64)
    // Event emitted when user borrows underlying from the pool
    pub event Borrow(borrower: Address, borrowAmount: UFix64, borrowerTotalBorrows: UFix64, poolTotalBorrows: UFix64);
    // Event emitted when user repays underlying to pool
    pub event Repay(borrower: Address, actualRepayAmount: UFix64, borrowerTotalBorrows: UFix64, poolTotalBorrows: UFix64)
    // Event emitted when pool reserves get added
    pub event ReserveAdded(donator: Address, addedUnderlyingAmount: UFix64, newTotalReserves: UFix64)
    // Event emitted when liquidation happenes
    pub event LiquidateBorrow(liquidator: Address, borrower: Address, actualRepaidUnderlying: UFix64, collateralPoolToSeize: Address, collateralPoolLpTokenSeized: UFix64)
    // Event emitted when interestRateModel is changed
    pub event NewInterestRateModel(_ oldInterestRateModelAddress: Address?, _ newInterestRateModelAddress: Address)
    // Event emitted when the reserveFactor is changed
    pub event NewReserveFactor(_ oldReserveFactor: UFix64, _ newReserveFactor: UFix64)
    // Event emitted when the poolSeizeShare is changed
    pub event NewPoolSeizeShare(_ oldPoolSeizeShare: UFix64, _ newPoolSeizeShare: UFix64)
    // Event emitted when the comptroller is changed
    pub event NewComptroller(_ oldComptrollerAddress: Address?, _ newComptrollerAddress: Address)

    // Return underlying asset's type of current pool
    pub fun getUnderlyingAssetType(): String {
        return self.underlyingAssetType.identifier
    }

    // Gets current underlying balance of this pool
    pub fun getPoolCash(): UFix64 {
        return self.underlyingVault.balance
    }

    // Calculates interest accrued from the last checkpointed block to the current block and 
    // applies to total borrows, total reserves, borrow index.
    access(self) fun accrueInterest(): Error {
        let currentBlockNumber = getCurrentBlock().height
        let accrualBlockNumberPrior = self.accrualBlockNumber
        // Return early if accrue 0 interest
        if (currentBlockNumber == accrualBlockNumberPrior) {
            return Error.NO_ERROR
        }
        let cashPrior = self.getPoolCash()
        let borrowPrior = self.totalBorrows
        let reservesPrior = self.totalReserves
        let borrowIndexPrior = self.borrowIndex

        if (self.interestRateModelCap?.check() != true) {
            return Error.CURRENT_INTEREST_RATE_MODEL_NULL
        }
        // Get the borrow interest rate per block
        let borrowRatePerBlock =
            self.interestRateModelCap!.borrow()!.getBorrowRate(cash: cashPrior, borrows: borrowPrior, reserves: reservesPrior)
        let blockDelta = currentBlockNumber - accrualBlockNumberPrior
        let simpleInterestFactor = borrowRatePerBlock * UFix64(blockDelta)
        let interestAccumulated = simpleInterestFactor * borrowPrior
        let totalBorrowsNew = interestAccumulated + borrowPrior
        let totalReservesNew = self.reserveFactor * interestAccumulated + reservesPrior
        let borrowIndexNew = simpleInterestFactor * borrowIndexPrior + borrowIndexPrior

        // Write calculated values into contract storage
        self.accrualBlockNumber = currentBlockNumber
        self.borrowIndex = borrowIndexNew
        self.totalBorrows = totalBorrowsNew
        self.totalReserves = totalReservesNew

        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
        return Error.NO_ERROR
    }

    // Calculates the exchange rate from the underlying to virtual lpToken (i.e. how many UnderlyingToken per virtual lpToken)
    // Note: This is for internal call only, it doesn't call accrueInterest() first to update with latest states which is 
    // used in calculating the exchange rate.
    access(self) fun underlyingToLpTokenRateSnapshot(): UFix64 {
        if (self.totalSupply == 0.0) {
            return self.initialExchangeRate
        } else {
            return (self.getPoolCash() + self.totalBorrows - self.totalReserves) / self.totalSupply
        }
    }
    // Calculates the borrow balance of borrower address based on stored states
    // Note: This is for internal call only, it doesn't call accrueInterest() first to update with latest states which is 
    // used in calculating the borrow balance.
    access(self) fun borrowBalanceSnapshot(borrowerAddress: Address): UFix64 {
        if (self.accountBorrows.containsKey(borrowerAddress) == false) {
            return 0.0
        }
        let borrower = self.accountBorrows[borrowerAddress]!
        return borrower.principal * self.borrowIndex / borrower.interestIndex
    }

    // Supplier deposits underlying asset's Vault into the pool
    // TODO: Check fake currency deposit? 
    pub fun supply(supplierAddr: Address, inUnderlyingVault: @FungibleToken.Vault) {
        pre {
            inUnderlyingVault.balance > 0.0: "Supplied empty underlying Vault"
            inUnderlyingVault.isInstance(self.underlyingAssetType): "supplied vault and pool underlying type mismatch, revert"
        }
        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "SUPPLY_ACCRUE_INTEREST_FAILED")

        // 2. Check whether or not supplyAllowed()
        let amount = inUnderlyingVault.balance
        let ret = self.comptrollerCap!.borrow()!.supplyAllowed(
            poolAddress: self.poolAddress,
            supplierAddress: supplierAddr,
            supplyUnderlyingAmount: amount
        )
        assert(ret == 0, message: "supply not allowed, error reason: ".concat(ret.toString()))

        // 3. Deposit into underlying vault and mint corresponding PoolTokens 
        let underlyingToken2LpTokenRate = self.underlyingToLpTokenRateSnapshot()
        let mintVirtualAmount = amount / underlyingToken2LpTokenRate
        self.accountLpTokens[supplierAddr] = mintVirtualAmount + (self.accountLpTokens[supplierAddr] ?? 0.0)
        self.totalSupply = self.totalSupply + mintVirtualAmount
        self.underlyingVault.deposit(from: <-inUnderlyingVault)

        emit Supply(suppliedUnderlyingAmount: amount, mintedLpTokenAmount: mintVirtualAmount)
    }

    access(self) fun redeemInternal(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        numLpTokenToRedeem: UFix64,
        numUnderlyingToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numLpTokenToRedeem == 0.0 || numUnderlyingToRedeem == 0.0: "numLpTokenToRedeem or numUnderlyingToRedeem must be 0.0"
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil: "Invalid user certificate."
        }

        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "REDEEM_ACCRUE_INTEREST_FAILED")
        
        let redeemer = userCertificateCap.borrow()!.owner!.address
        assert(self.accountLpTokens.containsKey(redeemer), message: "REDEEM_FAILED_REDEEMER_NOT_ENOUGH_LP_TOKEN")

        // 2. Check whether or not redeemAllowed()
        var lpTokenToRedeem = 0.0
        var underlyingToRedeem = 0.0
        let underlyingToLpRate = self.underlyingToLpTokenRateSnapshot()
        if (numLpTokenToRedeem == 0.0) {
            // redeem all
            if numUnderlyingToRedeem == UFix64.max {
                lpTokenToRedeem = self.accountLpTokens[redeemer]!
                underlyingToRedeem = lpTokenToRedeem * underlyingToLpRate
            } else {
                lpTokenToRedeem = numUnderlyingToRedeem / underlyingToLpRate
                underlyingToRedeem = numUnderlyingToRedeem
            }
        } else {
            if numLpTokenToRedeem == UFix64.max {
                lpTokenToRedeem = self.accountLpTokens[redeemer]!
            } else {
                lpTokenToRedeem = numLpTokenToRedeem
            }
            underlyingToRedeem = lpTokenToRedeem * underlyingToLpRate
        }
        
        assert(lpTokenToRedeem <= self.accountLpTokens[redeemer]!, message: "REDEEM_FAILED_REDEEMER_NOT_ENOUGH_LP_TOKEN")

        let ret = self.comptrollerCap!.borrow()!.redeemAllowed(
            poolAddress: self.poolAddress,
            redeemerAddress: redeemer,
            redeemLpTokenAmount: lpTokenToRedeem,
        )
        assert(ret == 0, message: "redeem not allowed, error reason: ".concat(ret.toString()))

        // 3. Burn virtual lpTokens, withdraw from underlying vault and return it
        assert(underlyingToRedeem <= self.getPoolCash(), message: "REDEEM_FAILED_NOT_ENOUGH_UNDERLYING_BALANCE")

        self.totalSupply = self.totalSupply - lpTokenToRedeem
        if (self.accountLpTokens[redeemer] == lpTokenToRedeem) {
            self.accountLpTokens.remove(key: redeemer)
        } else {
            self.accountLpTokens[redeemer] = self.accountLpTokens[redeemer]! - lpTokenToRedeem
        }
        emit Redeem(
            redeemer: redeemer,
            lpTokenToRedeem: lpTokenToRedeem,
            redeemedUnderlyingAmount: underlyingToRedeem
        )
        return <- self.underlyingVault.withdraw(amount: underlyingToRedeem)
    }

    // User redeems @numLpTokenToRedeem lpTokens for the underlying asset's vault
    // redeemer is inferred from the reference to the deposit Certificate, which can only be provided by the Certificate owner,
    // thus preventing passing in a fake redeemer
    // Since redeemer decreases his overall collateral ratio across all markets, safety check happenes inside comptroller
    pub fun redeem(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        numLpTokenToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numLpTokenToRedeem > 0.0: "Redeemed zero-balanced lpToken"
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil: "Invalid user certificate."
        }
        return <- self.redeemInternal(
            userCertificateCap: userCertificateCap,
            numLpTokenToRedeem: numLpTokenToRedeem,
            numUnderlyingToRedeem: 0.0
        )
    }

    pub fun redeemUnderlying(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        numUnderlyingToRedeem: UFix64
    ): @FungibleToken.Vault? {
        pre {
            numUnderlyingToRedeem > 0.0: "Redeemed zero-balanced underlying"
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil: "Invalid user certificate."
        }
        return <- self.redeemInternal(
            userCertificateCap: userCertificateCap,
            numLpTokenToRedeem: 0.0,
            numUnderlyingToRedeem: numUnderlyingToRedeem
        )
    }

    // User borrows underlying asset from the pool.
    // borrower is inferred from the reference to the deposit Certificate, which can only be provided by the Certificate owner,
    // thus preventing passing in a fake borrower
    // Since borrower would decrease his overall collateral ratio across all markets, safety check happenes inside comptroller
    pub fun borrow(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        borrowAmount: UFix64,
    ): @FungibleToken.Vault {
        pre {
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil: "Invalid user certificate."
            borrowAmount > 0.0: "borrowAmount zero"
            borrowAmount <= self.getPoolCash(): "Pool not enough underlying balance for borrow"
        }
        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "BORROW_ACCRUE_INTEREST_FAILED")

        // 2. Check whether or not borrowAllowed()
        let borrower = userCertificateCap.borrow()!.owner!.address
        let ret = self.comptrollerCap!.borrow()!.borrowAllowed(
            poolAddress: self.poolAddress,
            borrowerAddress: borrower,
            borrowUnderlyingAmount: borrowAmount
        )
        assert(ret == 0, message: "borrow not allowed, error reason: ".concat(ret.toString()))

        // 3. Updates borrow states, withdraw from pool underlying vault and deposits into borrower's account
        self.totalBorrows = self.totalBorrows + borrowAmount
        let borrowBalanceNew = borrowAmount + self.borrowBalanceSnapshot(borrowerAddress: borrower)
        self.accountBorrows[borrower] = BorrowSnapshot(principal: borrowBalanceNew, interestIndex: self.borrowIndex)
        emit Borrow(borrower: borrower, borrowAmount: borrowAmount, borrowerTotalBorrows: borrowBalanceNew, poolTotalBorrows: self.totalBorrows);
        return <- self.underlyingVault.withdraw(amount: borrowAmount)
    }

    // Note: caller ensures that LendingPool.accrueInterest() has been called with latest states checkpointed
    access(self) fun repayBorrowInternal(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        // Check whether or not repayAllowed()
        let repayAmount = repayUnderlyingVault.balance
        let accountTotalBorrows = self.borrowBalanceSnapshot(borrowerAddress: borrower)
        let actualRepayAmount = accountTotalBorrows > repayAmount ? repayAmount : accountTotalBorrows
        let ret = self.comptrollerCap!.borrow()!.repayAllowed(
            poolAddress: self.poolAddress,
            borrowerAddress: borrower,
            repayUnderlyingAmount: actualRepayAmount
        )
        assert(ret == 0, message: "repay not allowed, error reason: ".concat(ret.toString()))

        // Updates borrow states, deposit repay Vault into pool underlying vault and return any remaining Vault
        let accountTotalBorrowsNew = accountTotalBorrows > repayAmount ? accountTotalBorrows - repayAmount : 0.0
        self.underlyingVault.deposit(from: <-repayUnderlyingVault)
        self.totalBorrows = self.totalBorrows - actualRepayAmount
        emit Repay(borrower: borrower, actualRepayAmount: actualRepayAmount, borrowerTotalBorrows: accountTotalBorrowsNew, poolTotalBorrows: self.totalBorrows);
        if (accountTotalBorrows > repayAmount) {
            self.accountBorrows[borrower] = BorrowSnapshot(principal: accountTotalBorrowsNew, interestIndex: self.borrowIndex)
            return nil
        } else {
            self.accountBorrows.remove(key: borrower)
            return <- self.underlyingVault.withdraw(amount: repayAmount - accountTotalBorrows)
        }
    }

    // User repays borrow with a underlying Vault and receives a new underlying Vault if there's still any remaining left.
    // Note that the borrower address can potentially not be the same as the repayer address (which means someone can repay on behave of borrower),
    // this is allowed as there's no safety issue to do so.
    pub fun repayBorrow(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.balance > 0.0: "repayed with empty underlying Vault"
            repayUnderlyingVault.isInstance(self.underlyingAssetType): "repayed vault and pool underlying type mismatch, revert"
        }
        // Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "REPAY_BORROW_ACCRUE_INTEREST_FAILED")

        return <- self.repayBorrowInternal(borrower: borrower, repayUnderlyingVault: <-repayUnderlyingVault)
    }

    pub fun liquidate(
        liquidator: Address,
        borrower: Address,
        poolCollateralizedToSeize: Address,
        repayUnderlyingVault: @FungibleToken.Vault
    ): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.isInstance(self.underlyingAssetType): "liquidator repayed vault and pool underlying type mismatch, revert"
        }

        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "LIQUIDATE_ACCRUE_INTEREST_FAILED")

        // 2. Check whether or not liquidateAllowed()
        let underlyingAmountToRepay = repayUnderlyingVault.balance
        let ret = self.comptrollerCap!.borrow()!.liquidateAllowed(
            poolBorrowed: self.poolAddress,
            poolCollateralized: poolCollateralizedToSeize,
            borrower: borrower,
            repayUnderlyingAmount: underlyingAmountToRepay
        )
        assert(ret == 0, message: "liquidate not allowed, error reason: ".concat(ret.toString()))

        // 3. Liquidator repays on behave of borrower
        assert(liquidator != borrower, message: "LIQUIDATE_LIQUIDATOR_IS_BORROWER")
        let remainingVault <- self.repayBorrowInternal(borrower: borrower, repayUnderlyingVault: <-repayUnderlyingVault)
        let remainingAmount = remainingVault?.balance ?? 0.0
        let actualRepayAmount = underlyingAmountToRepay - remainingAmount
        // Calculate collateralLpTokenSeizedAmount based on actualRepayAmount
        let collateralLpTokenSeizedAmount = self.comptrollerCap!.borrow()!.calculateCollateralPoolLpTokenToSeize(
            borrower: borrower,
            borrowPool: self.poolAddress,
            collateralPool: poolCollateralizedToSeize,
            actualRepaidBorrowAmount: actualRepayAmount
        )

        // 4. seizeInternal if current pool is also borrower's collateralPool;
        // otherwise delegate to comptroller to seize another external collateralPool
        if (poolCollateralizedToSeize == self.poolAddress) {
            self.seizeInternal(
                borrowPool: self.poolAddress,
                liquidator: liquidator,
                borrower: borrower,
                borrowerLpTokenToSeize: collateralLpTokenSeizedAmount
            )
        } else {
            // Get local pool's certificate
            let localPoolCertificateCap = self.account.getCapability<&{Interfaces.IdentityCertificate}>(Config.PoolCertificatePrivatePath)
            // Get remote pool's seize function
            let remotePoolPublicCap = getAccount(poolCollateralizedToSeize).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPath)
            assert(remotePoolPublicCap.check(), message: "Invalid remote call pool")
            remotePoolPublicCap.borrow()!.seize(
                fromPoolCertificateCap: localPoolCertificateCap,
                borrowPool: self.poolAddress,
                liquidator: liquidator,
                borrower: borrower,
                borrowerCollateralLpTokenToSeize: collateralLpTokenSeizedAmount
            )
        }

        emit LiquidateBorrow(
            liquidator: liquidator,
            borrower: borrower,
            actualRepaidUnderlying: actualRepayAmount,
            collateralPoolToSeize: poolCollateralizedToSeize,
            collateralPoolLpTokenSeized: collateralLpTokenSeizedAmount
        )
        return <-remainingVault
    }

    // Used for "external" called seize. Run-time type check of certificate ensures it can only be called by pools in comptroller's markets.
    pub fun seize(
        fromPoolCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        borrowPool: Address,
        liquidator: Address,
        borrower: Address,
        borrowerCollateralLpTokenToSeize: UFix64
    ) {
        pre {
            self.comptrollerCap!.check(): "Lost comptroller"
            fromPoolCertificateCap.check() && fromPoolCertificateCap.borrow()!.owner != nil: "Invalid pool certificate."
            // The caller of this seize function must be the pool contract which is added in the markets.
            self.comptrollerCap!.borrow()!.identifyPoolCertificate(poolCertificateCap: fromPoolCertificateCap) == 0: "Invalid pool certificate"
        }

        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "SEIZE_ACCRUE_INTEREST_FAILED")

        // 2. seizeInternal
        self.seizeInternal(
            borrowPool: borrowPool,
            liquidator: liquidator,
            borrower: borrower,
            borrowerLpTokenToSeize: borrowerCollateralLpTokenToSeize
        )
    }

    // Caller ensures accrueInterest() has been called
    access(self) fun seizeInternal(
        borrowPool: Address,
        liquidator: Address,
        borrower: Address,
        borrowerLpTokenToSeize: UFix64
    ) {
        pre {
            liquidator != borrower: "seize: liquidator is borrower, revert"
        }
        let ret = self.comptrollerCap!.borrow()!.seizeAllowed(
            borrowPool: borrowPool,
            collateralPool: self.poolAddress,
            liquidator: liquidator,
            borrower: borrower,
            seizeCollateralPoolLpTokenAmount: borrowerLpTokenToSeize
        )
        assert(ret == 0, message: "seize not allowed, error reason: ".concat(ret.toString()))

        // accountLpTokens[borrower] -= collateralPoolLpTokenToSeize
        // LendingPool.totalReserves += collateralPoolLpTokenToSeize * LendingPool.poolSeizeShare
        // accountLpTokens[liquidator] += (collateralPoolLpTokenToSeize * (1 - LendingPool.poolSeizeShare))
        let protocolSeizedLpTokens = borrowerLpTokenToSeize * self.poolSeizeShare
        let liquidatorSeizedLpTokens = borrowerLpTokenToSeize - protocolSeizedLpTokens
        let underlyingToLpTokenRate = self.underlyingToLpTokenRateSnapshot()
        let addedUnderlyingReserves = underlyingToLpTokenRate * protocolSeizedLpTokens
        self.totalReserves = self.totalReserves + addedUnderlyingReserves
        self.totalSupply = self.totalSupply - protocolSeizedLpTokens
        // in-place liquidation: only virtual lpToken records get updated, no token deposit / withdraw needs to happen
        self.accountLpTokens[borrower] = self.accountLpTokens[borrower]! - borrowerLpTokenToSeize
        self.accountLpTokens[liquidator] = self.accountLpTokens[liquidator]! + liquidatorSeizedLpTokens

        emit ReserveAdded(donator: self.poolAddress, addedUnderlyingAmount: addedUnderlyingReserves, newTotalReserves: self.totalReserves)
    }

    // This certificate identify the address and needs to be stored in storage path locally.
    // User should keep it safe and never give this resource's capability to others
    pub resource UserCertificate: Interfaces.IdentityCertificate {
        // The distributor's type of this certificate
        pub let authorityType: Type
        init() {
            self.authorityType = LendingPool.getType()
        }
    }
    pub fun IssueUserCertificate(): @UserCertificate {
        return <- create UserCertificate()
    }

    pub resource PoolCertificate: Interfaces.IdentityCertificate {
        // The distributor's type of this certificate
        pub let authorityType: Type
        init() {
            self.authorityType = LendingPool.getType()
        }
    }

    pub resource PoolPublic: Interfaces.PoolPublic {
        pub fun getPoolAddress(): Address {
            return LendingPool.poolAddress
        }
        pub fun getPoolTypeString(): String {
            return LendingPool.getType().identifier
        }
        pub fun getUnderlyingTypeString(): String {
            return LendingPool.getUnderlyingAssetType()
        }
        pub fun getUnderlyingToLpTokenRate(): UFix64 {
            return LendingPool.underlyingToLpTokenRateSnapshot()
        }
        pub fun getAccountLpTokenBalance(account: Address): UFix64 {
            return LendingPool.accountLpTokens[account] ?? 0.0
        }
        pub fun getAccountBorrowBalance(account: Address): UFix64 {
            return LendingPool.borrowBalanceSnapshot(borrowerAddress: account)
        }
        pub fun getAccountSnapshot(account: Address): [UFix64; 3] {
            return [
                self.getUnderlyingToLpTokenRate(),
                self.getAccountLpTokenBalance(account: account),
                self.getAccountBorrowBalance(account: account)
            ]
        }
        pub fun getPoolTotalBorrows(): UFix64 {
            return LendingPool.totalBorrows
        }
        pub fun accrueInterest(): UInt8 {
            let ret = LendingPool.accrueInterest()
            return ret as! UInt8
        }
        pub fun getPoolCertificateType(): Type {
            return Type<@LendingPool.PoolCertificate>()
        }
        pub fun seize(
            fromPoolCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
            borrowPool: Address,
            liquidator: Address,
            borrower: Address,
            borrowerCollateralLpTokenToSeize: UFix64
        ) {
            LendingPool.seize(
                fromPoolCertificateCap: fromPoolCertificateCap,
                borrowPool: borrowPool,
                liquidator: liquidator,
                borrower: borrower,
                borrowerCollateralLpTokenToSeize: borrowerCollateralLpTokenToSeize
            )
        }
    }

    pub resource PoolAdmin {
        // Admin function to call accrueInterest() to checkpoint latest states, and then update the interest rate model
        pub fun setInterestRateModel(newInterestRateModelAddress: Address): Error {
            let err = LendingPool.accrueInterest()
            if (err != Error.NO_ERROR) {
                return Error.SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED
            }
            if (newInterestRateModelAddress != LendingPool.interestRateModelAddress) {
                let oldInterestRateModelAddress = LendingPool.interestRateModelAddress
                LendingPool.interestRateModelAddress = newInterestRateModelAddress
                LendingPool.interestRateModelCap = getAccount(newInterestRateModelAddress)
                    .getCapability<&{Interfaces.InterestRateModelPublic}>(TwoSegmentsInterestRateModel.InterestRateModelPublicPath)
                emit NewInterestRateModel(oldInterestRateModelAddress, newInterestRateModelAddress)
            }
            return Error.NO_ERROR
        }

        // Admin function to call accrueInterest() to checkpoint latest states, and then update reserveFactor
        pub fun setReserveFactor(newReserveFactor: UFix64): Error {
            let err = LendingPool.accrueInterest()
            if (err != Error.NO_ERROR) {
                return Error.SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED
            }
            if (newReserveFactor > 1.0) {
                return Error.SET_RESERVE_FACTOR_OUT_OF_RANGE
            }
            let oldReserveFactor = LendingPool.reserveFactor
            LendingPool.reserveFactor = newReserveFactor
            emit NewReserveFactor(oldReserveFactor, newReserveFactor);
            return Error.NO_ERROR
        }

        // Admin function to update poolSeizeShare
        pub fun setPoolSeizeShare(newPoolSeizeShare: UFix64): Error {
            if (newPoolSeizeShare > 1.0) {
                return Error.SET_POOL_SEIZE_SHARE_OUT_OF_RANGE
            }
            let oldPoolSeizeShare = LendingPool.poolSeizeShare
            LendingPool.poolSeizeShare = newPoolSeizeShare
            emit NewPoolSeizeShare(oldPoolSeizeShare, newPoolSeizeShare);
            return Error.NO_ERROR
        }

        // Admin function to set comptroller
        pub fun setComptroller(newComptrollerAddress: Address) {
            post {
                LendingPool.comptrollerCap != nil && LendingPool.comptrollerCap!.check() == true: "Set new Comptroller fail."
            }
            
            if (newComptrollerAddress != LendingPool.comptrollerAddress) {
                let oldComptrollerAddress = LendingPool.comptrollerAddress
                LendingPool.comptrollerAddress = newComptrollerAddress
                LendingPool.comptrollerCap = getAccount(newComptrollerAddress)
                    .getCapability<&{Interfaces.ComptrollerPublic}>(ComptrollerV1.ComptrollerPublicPath)
                emit NewComptroller(oldComptrollerAddress, newComptrollerAddress)
            }
        }

        // Admin function to initialize pool.
        // Note: can be called only once
        pub fun initializePool(
            reserveFactor: UFix64,
            poolSeizeShare: UFix64,
            interestRateModelAddress: Address
        ) {
            pre {
                LendingPool.accrualBlockNumber == 0 && LendingPool.borrowIndex == 0.0: "Pool can only be initialized once"
                reserveFactor <= 1.0 && poolSeizeShare <= 1.0: "reserveFactor | poolSeizeShare out of range 1.0"
            }
            post {
                LendingPool.interestRateModelCap != nil && LendingPool.interestRateModelCap!.check() == true: "InterestRateModel not properly initialized"
            }
            LendingPool.accrualBlockNumber = getCurrentBlock().height
            LendingPool.borrowIndex = 1.0
            LendingPool.reserveFactor = reserveFactor
            LendingPool.poolSeizeShare = poolSeizeShare
            LendingPool.interestRateModelAddress = interestRateModelAddress
            LendingPool.interestRateModelCap = getAccount(interestRateModelAddress)
                .getCapability<&{Interfaces.InterestRateModelPublic}>(TwoSegmentsInterestRateModel.InterestRateModelPublicPath)
        }
    }

    //init(anyFungibleVault: @FungibleToken.Vault) {
    init() {
        self.PoolAdminStoragePath = /storage/poolAdmin
        self.UnderlyingAssetVaultStoragePath = /storage/poolUnderlyingAssetVault
        self.PoolPublicStoragePath = /storage/poolPublic

        self.poolAddress = self.account.address
        self.initialExchangeRate = 1.0
        self.accrualBlockNumber = 0
        self.borrowIndex = 0.0
        self.totalBorrows = 0.0
        self.totalReserves = 0.0
        self.reserveFactor = 0.0
        self.poolSeizeShare = 0.0
        self.totalSupply = 0.0
        self.accountLpTokens = {}
        self.accountBorrows = {}
        self.interestRateModelAddress = nil
        self.interestRateModelCap = nil
        self.comptrollerAddress = nil
        self.comptrollerCap = nil
        self.underlyingVault <- self.account.load<@FungibleToken.Vault>(from: /storage/underlyingVault) ?? panic("Lost local overlying vault.")
        self.underlyingAssetType = self.underlyingVault.getType()
        assert(self.underlyingVault.balance == 0.0, message: "must initialize pool with zero-balanced underlying asset vault")
        // save pool admin
        self.account.save(<-create PoolAdmin(), to: self.PoolAdminStoragePath)
        // save pool public interface
        self.account.save(<-create PoolPublic(), to: self.PoolPublicStoragePath)
        self.account.link<&{Interfaces.PoolPublic}>(Config.PoolPublicPath, target: self.PoolPublicStoragePath)
        // save pool certificate
        self.account.save(<-create PoolCertificate(), to: Config.PoolCertificateStoragePath)
        self.account.link<&{Interfaces.IdentityCertificate}>(Config.PoolCertificatePrivatePath, target: Config.PoolCertificateStoragePath)

        emit TokensInitialized(initialSupply: 0.0)
    }
}