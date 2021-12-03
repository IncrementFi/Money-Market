import FungibleToken from "./FungibleToken.cdc"
import Interfaces from "./Interfaces.cdc"
import Config from "./Config.cdc"

pub contract LendingPool {
    pub let PoolAdminStoragePath: StoragePath
    pub let UnderlyingAssetVaultStoragePath: StoragePath
    pub let PoolPublicStoragePath: StoragePath
    pub let PoolPublicPublicPath: PublicPath

    // Account address the pool is deployed to, i.e. the pool 'contract address'
    pub let poolAddress: Address
    // Initial exchange rate (when LendingPool.totalSupply == 0) between the virtual lpToken and pool underlying token
    pub let scaledInitialExchangeRate: UInt256
    // Block number that interest was last accrued at
    pub var accrualBlockNumber: UInt256
    // Accumulator of the total earned interest rate since the opening of the market, scaled up by 1e18
    pub var scaledBorrowIndex: UInt256
    // Total amount of outstanding borrows of the underlying in this market, scaled up by 1e18
    pub var scaledTotalBorrows: UInt256
    // Total amount of reserves of the underlying held in this market, scaled up by 1e18
    pub var scaledTotalReserves: UInt256
    // Total number of virtual lpTokens, scaled up by 1e18
    pub var scaledTotalSupply: UInt256
    // Fraction of generated interest added to protocol reserves, scaled up by 1e18
    // Must be in [0.0, 1.0] x scaleFactor
    pub var scaledReserveFactor: UInt256
    // Share of seized collateral that is added to reserves when liquidation happenes, e.g. 0.028 x 1e18.
    // Must be in [0.0, 1.0] x scaleFactor
    pub var scaledPoolSeizeShare: UInt256
    // { supplierAddress => # of virtual lpToken the supplier owns, scaled up by 1e18 }
    access(self) let accountLpTokens: {Address: UInt256}

    pub struct BorrowSnapshot {
        // Total balance (with accrued interest), after applying the most recent balance-change action
        pub var scaledPrincipal: UInt256
        // Global borrowIndex as of the most recent balance-change action
        pub var scaledInterestIndex: UInt256
    
        init(principal: UInt256, interestIndex: UInt256) {
            self.scaledPrincipal = principal
            self.scaledInterestIndex = interestIndex
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

    // Event emitted when interest is accrued
    pub event AccrueInterest(_ scaledCashPrior: UInt256, _ scaledInterestAccumulated: UInt256, _ scaledBorrowIndexNew: UInt256, _ scaledTotalBorrowsNew: UInt256)
    // Event emitted when underlying asset is deposited into pool
    pub event Supply(supplier: Address, scaledSuppliedUnderlyingAmount: UInt256, scaledMintedLpTokenAmount: UInt256)
    // Event emitted when virtual lpToken is burnt and redeemed for underlying asset
    pub event Redeem(redeemer: Address, scaledLpTokenToRedeem: UInt256, scaledRedeemedUnderlyingAmount: UInt256)
    // Event emitted when user borrows underlying from the pool
    pub event Borrow(borrower: Address, scaledBorrowAmount: UInt256, scaledBorrowerTotalBorrows: UInt256, scaledPoolTotalBorrows: UInt256);
    // Event emitted when user repays underlying to pool
    pub event Repay(borrower: Address, scaledActualRepayAmount: UInt256, scaledBorrowerTotalBorrows: UInt256, scaledPoolTotalBorrows: UInt256)
    // Event emitted when pool reserves get added
    pub event ReservesAdded(donator: Address, scaledAddedUnderlyingAmount: UInt256, scaledNewTotalReserves: UInt256)
    // Event emitted when pool reserves is reduced
    pub event ReservesReduced(scaledReduceAmount: UInt256, scaledNewTotalReserves: UInt256)
    // Event emitted when liquidation happenes
    pub event Liquidate(liquidator: Address, borrower: Address, scaledActualRepaidUnderlying: UInt256, collateralPoolToSeize: Address, scaledCollateralPoolLpTokenSeized: UInt256)
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

    // Gets current underlying balance of this pool, scaled up by 1e18
    pub fun getPoolCash(): UInt256 {
        return Config.UFix64ToScaledUInt256(self.underlyingVault.balance)
    }

    // Calculates interest accrued from the last checkpointed block to the current block and 
    // applies to total borrows, total reserves, borrow index.
    pub fun accrueInterest() {
        pre {
            self.interestRateModelCap != nil && self.interestRateModelCap!.check() == true:
                Config.ErrorEncode (
                    msg: "Invalid interest rate model cap in pool ".concat(LendingPool.poolAddress.toString()),
                    err: Config.Error.LOST_INTEREST_RATE_MODEL_CAP_IN_POOL
                )
        }
        let currentBlockNumber = UInt256(getCurrentBlock().height)
        let accrualBlockNumberPrior = self.accrualBlockNumber
        // Return early if accrue 0 interest
        if (currentBlockNumber == accrualBlockNumberPrior) {
            return
        }
        let scaledCashPrior = self.getPoolCash()
        let scaledBorrowPrior = self.scaledTotalBorrows
        let scaledReservesPrior = self.scaledTotalReserves
        let scaledBorrowIndexPrior = self.scaledBorrowIndex

        // Get scaled borrow interest rate per block
        let scaledBorrowRatePerBlock =
            self.interestRateModelCap!.borrow()!.getBorrowRate(cash: scaledCashPrior, borrows: scaledBorrowPrior, reserves: scaledReservesPrior)
        let blockDelta = currentBlockNumber - accrualBlockNumberPrior
        let scaledInterestFactor = scaledBorrowRatePerBlock * blockDelta
        let scaleFactor = Config.scaleFactor
        let scaledInterestAccumulated = scaledInterestFactor * scaledBorrowPrior / scaleFactor
        let scaledTotalBorrowsNew = scaledInterestAccumulated + scaledBorrowPrior
        let scaledTotalReservesNew = self.scaledReserveFactor * scaledInterestAccumulated / scaleFactor + scaledReservesPrior
        let scaledBorrowIndexNew = scaledInterestFactor * scaledBorrowIndexPrior / scaleFactor + scaledBorrowIndexPrior

        // Write calculated values into contract storage
        self.accrualBlockNumber = currentBlockNumber
        self.scaledBorrowIndex = scaledBorrowIndexNew
        self.scaledTotalBorrows = scaledTotalBorrowsNew
        self.scaledTotalReserves = scaledTotalReservesNew

        emit AccrueInterest(scaledCashPrior, scaledInterestAccumulated, scaledBorrowIndexNew, scaledTotalBorrowsNew);
        return
    }

    // Calculates the exchange rate from the underlying to virtual lpToken (i.e. how many UnderlyingToken per virtual lpToken)
    // Note: It doesn't call accrueInterest() first to update with latest states which is used in calculating the exchange rate.
    pub fun underlyingToLpTokenRateSnapshotScaled(): UInt256 {
        if (self.scaledTotalSupply == 0) {
            return self.scaledInitialExchangeRate
        } else {
            return (self.getPoolCash() + self.scaledTotalBorrows - self.scaledTotalReserves) * Config.scaleFactor / self.scaledTotalSupply
        }
    }
    // Calculates the scaled borrow balance of borrower address based on stored states
    // Note: It doesn't call accrueInterest() first to update with latest states which is used in calculating the borrow balance.
    pub fun borrowBalanceSnapshotScaled(borrowerAddress: Address): UInt256 {
        if (self.accountBorrows.containsKey(borrowerAddress) == false) {
            return 0
        }
        let borrower = self.accountBorrows[borrowerAddress]!
        return borrower.scaledPrincipal * self.scaledBorrowIndex / borrower.scaledInterestIndex
    }

    // Check whether or not the given certificate is issued by system
    access(self) fun checkUserCertificateType(certCap: Capability<&{Interfaces.IdentityCertificate}>): Bool {
        return certCap.borrow()!.isInstance(self.comptrollerCap!.borrow()!.getUserCertificateType())
    }

    // Supplier deposits underlying asset's Vault into the pool
    pub fun supply(supplierAddr: Address, inUnderlyingVault: @FungibleToken.Vault) {
        pre {
            inUnderlyingVault.balance > 0.0: 
                Config.ErrorEncode (
                    msg: "Supplied empty underlying Vault.",
                    err: Config.Error.EMPTY_INPUT_FUNGIBLETOKEN_VAULT
                )
            inUnderlyingVault.isInstance(self.underlyingAssetType):
                Config.ErrorEncode (
                    msg: "Supplied vault and pool underlying type mismatch, revert.",
                    err: Config.Error.MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
                )
        }
        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Check whether or not supplyAllowed()
        let scaledAmount = Config.UFix64ToScaledUInt256(inUnderlyingVault.balance)
        
        self.comptrollerCap!.borrow()!.supplyAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            supplierAddress: supplierAddr,
            supplyUnderlyingAmountScaled: scaledAmount
        )
        
        // 3. Deposit into underlying vault and mint corresponding PoolTokens 
        let underlyingToken2LpTokenRateScaled = self.underlyingToLpTokenRateSnapshotScaled()
        let scaledMintVirtualAmount = scaledAmount * Config.scaleFactor / underlyingToken2LpTokenRateScaled
        self.accountLpTokens[supplierAddr] = scaledMintVirtualAmount + (self.accountLpTokens[supplierAddr] ?? (0 as UInt256))
        self.scaledTotalSupply = self.scaledTotalSupply + scaledMintVirtualAmount
        self.underlyingVault.deposit(from: <-inUnderlyingVault)

        emit Supply(supplier: supplierAddr, scaledSuppliedUnderlyingAmount: scaledAmount, scaledMintedLpTokenAmount: scaledMintVirtualAmount)
    }

    access(self) fun redeemInternal(
        redeemer: Address,
        numLpTokenToRedeem: UFix64,
        numUnderlyingToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numLpTokenToRedeem == 0.0 || numUnderlyingToRedeem == 0.0:
                Config.ErrorEncode (
                    msg: "numLpTokenToRedeem or numUnderlyingToRedeem must be 0.0.",
                    err: Config.Error.INVALID_PARAMETERS
                )
            self.accountLpTokens.containsKey(redeemer):
                Config.ErrorEncode (
                    msg: "redeemer has no liquidity, nothing to redeem.",
                    err: Config.Error.REDEEM_FAILED_NO_ENOUGH_LP_TOKEN
                )
        }

        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Check whether or not redeemAllowed()
        var scaledLpTokenToRedeem: UInt256 = 0
        var scaledUnderlyingToRedeem: UInt256 = 0
        let scaledUnderlyingToLpRate = self.underlyingToLpTokenRateSnapshotScaled()
        let scaleFactor = Config.scaleFactor
        if (numLpTokenToRedeem == 0.0) {
            // redeem all
            if numUnderlyingToRedeem == UFix64.max {
                scaledLpTokenToRedeem = self.accountLpTokens[redeemer]!
                scaledUnderlyingToRedeem = scaledLpTokenToRedeem * scaledUnderlyingToLpRate / scaleFactor
            } else {
                scaledLpTokenToRedeem = Config.UFix64ToScaledUInt256(numUnderlyingToRedeem) * scaleFactor / scaledUnderlyingToLpRate
                scaledUnderlyingToRedeem = Config.UFix64ToScaledUInt256(numUnderlyingToRedeem)
            }
        } else {
            if numLpTokenToRedeem == UFix64.max {
                scaledLpTokenToRedeem = self.accountLpTokens[redeemer]!
            } else {
                scaledLpTokenToRedeem = Config.UFix64ToScaledUInt256(numLpTokenToRedeem)
            }
            scaledUnderlyingToRedeem = scaledLpTokenToRedeem * scaledUnderlyingToLpRate / scaleFactor
        }
        
        assert(scaledLpTokenToRedeem <= self.accountLpTokens[redeemer]!, message: 
            Config.ErrorEncode (
                msg: "Redeemer does not have enough lp tokens to redeem.",
                err: Config.Error.REDEEM_FAILED_NO_ENOUGH_LP_TOKEN
            )
        )

        self.comptrollerCap!.borrow()!.redeemAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            redeemerAddress: redeemer,
            redeemLpTokenAmountScaled: scaledLpTokenToRedeem,
        )
        
        // 3. Burn virtual lpTokens, withdraw from underlying vault and return it
        assert(scaledUnderlyingToRedeem <= self.getPoolCash(), message:
            Config.ErrorEncode (
                msg: "The liquidity of pool is temporarily insufficient for redeem.",
                err: Config.Error.INSUFFICIENT_POOL_LIQUIDITY
            )
        )

        self.scaledTotalSupply = self.scaledTotalSupply - scaledLpTokenToRedeem
        if (self.accountLpTokens[redeemer] == scaledLpTokenToRedeem) {
            self.accountLpTokens.remove(key: redeemer)
        } else {
            self.accountLpTokens[redeemer] = self.accountLpTokens[redeemer]! - scaledLpTokenToRedeem
        }
        emit Redeem(
            redeemer: redeemer,
            scaledLpTokenToRedeem: scaledLpTokenToRedeem,
            scaledRedeemedUnderlyingAmount: scaledUnderlyingToRedeem
        )
        let amountUnderlyingToRedeem = Config.ScaledUInt256ToUFix64(scaledUnderlyingToRedeem)
        return <- self.underlyingVault.withdraw(amount: amountUnderlyingToRedeem)
    }

    // User redeems @numLpTokenToRedeem lpTokens for the underlying asset's vault
    // Note: redeemerAddress is inferred from the private capability to the IdentityCertificate resource,
    // which is stored in user account and can only be given by its owner
    // @numLpTokenToRedeem - the special value of `UFIx64.max` indicating to redeem all virtual LP tokens the redeemer has
    // Since redeemer decreases his overall collateral ratio across all markets, safety check happenes inside comptroller
    pub fun redeem(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        numLpTokenToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numLpTokenToRedeem > 0.0:
                Config.ErrorEncode (
                    msg: "Redeemed zero-balanced lpToken.",
                    err: Config.Error.INVALID_PARAMETERS
                )
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil:
                Config.ErrorEncode (
                    msg: "Cannot borrow reference to invalid UserCertificate.",
                    err: Config.Error.INVALID_USER_CERTIFICATE
                )
            self.checkUserCertificateType(certCap: userCertificateCap):
                Config.ErrorEncode (
                    msg: "Certificate not issued by system",
                    err: Config.Error.INVALID_USER_CERTIFICATE
                )
        }
        let redeemerAddress = userCertificateCap.borrow()!.owner!.address
        return <- self.redeemInternal(
            redeemer: redeemerAddress,
            numLpTokenToRedeem: numLpTokenToRedeem,
            numUnderlyingToRedeem: 0.0
        )
    }

    // User redeems @numUnderlyingToRedeem underlying FungibleTokens
    // @numUnderlyingToRedeem - the special value of `UFIx64.max` indicating to redeem all the underlying liquidity
    // the redeemer has provided to this pool
    pub fun redeemUnderlying(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        numUnderlyingToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numUnderlyingToRedeem > 0.0: Config.ErrorEncode ( msg: "Redeemed zero-balanced underlying", err: Config.Error.INVALID_PARAMETERS )
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil:
                Config.ErrorEncode (
                    msg: "Cannot borrow reference to invalid UserCertificate.",
                    err: Config.Error.INVALID_USER_CERTIFICATE
                )
            self.checkUserCertificateType(certCap: userCertificateCap):
                Config.ErrorEncode (
                    msg: "Certificate not issued by system",
                    err: Config.Error.INVALID_USER_CERTIFICATE
                )
        }
        let redeemerAddress = userCertificateCap.borrow()!.owner!.address
        return <- self.redeemInternal(
            redeemer: redeemerAddress,
            numLpTokenToRedeem: 0.0,
            numUnderlyingToRedeem: numUnderlyingToRedeem
        )
    }

    // User borrows underlying asset from the pool.
    // Note: borrowerAddress is inferred from the private capability to the IdentityCertificate resource,
    // which is stored in user account and can only be given by its owner
    // Since borrower would decrease his overall collateral ratio across all markets, safety check happenes inside comptroller
    pub fun borrow(
        userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>,
        borrowAmount: UFix64,
    ): @FungibleToken.Vault {
        pre {
            borrowAmount > 0.0: Config.ErrorEncode ( msg: "borrowAmount zero", err: Config.Error.INVALID_PARAMETERS )
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil:
                Config.ErrorEncode (
                    msg: "Cannot borrow reference to invalid UserCertificate.",
                    err: Config.Error.INVALID_USER_CERTIFICATE
                )
            self.checkUserCertificateType(certCap: userCertificateCap):
                Config.ErrorEncode (
                    msg: "Certificate not issued by system",
                    err: Config.Error.INVALID_USER_CERTIFICATE
                )
        }
        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Pool liquidity check
        let scaledBorrowAmount = Config.UFix64ToScaledUInt256(borrowAmount)
        assert(scaledBorrowAmount <= self.getPoolCash(), message:
            Config.ErrorEncode (
                msg: "The liquidity of pool is temporarily insufficient for borrow.",
                err: Config.Error.INSUFFICIENT_POOL_LIQUIDITY
            )
        )

        // 3. Check whether or not borrowAllowed()
        let borrower = userCertificateCap.borrow()!.owner!.address
        
        self.comptrollerCap!.borrow()!.borrowAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            borrowerAddress: borrower,
            borrowUnderlyingAmountScaled: scaledBorrowAmount
        )
        
        // 4. Updates borrow states, withdraw from pool underlying vault and deposits into borrower's account
        self.scaledTotalBorrows = self.scaledTotalBorrows + scaledBorrowAmount
        let scaledBorrowBalanceNew = scaledBorrowAmount + self.borrowBalanceSnapshotScaled(borrowerAddress: borrower)
        self.accountBorrows[borrower] = BorrowSnapshot(principal: scaledBorrowBalanceNew, interestIndex: self.scaledBorrowIndex)
        emit Borrow(borrower: borrower, scaledBorrowAmount: scaledBorrowAmount, scaledBorrowerTotalBorrows: scaledBorrowBalanceNew, scaledPoolTotalBorrows: self.scaledTotalBorrows);
        return <- self.underlyingVault.withdraw(amount: borrowAmount)
    }

    // Note: caller ensures that LendingPool.accrueInterest() has been called with latest states checkpointed
    access(self) fun repayBorrowInternal(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        // Check whether or not repayAllowed()
        let scaledRepayAmount = Config.UFix64ToScaledUInt256(repayUnderlyingVault.balance)
        let scaledAccountTotalBorrows = self.borrowBalanceSnapshotScaled(borrowerAddress: borrower)
        let scaledActualRepayAmount = scaledAccountTotalBorrows > scaledRepayAmount ? scaledRepayAmount : scaledAccountTotalBorrows
        
        self.comptrollerCap!.borrow()!.repayAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            borrowerAddress: borrower,
            repayUnderlyingAmountScaled: scaledActualRepayAmount
        )
        
        // Updates borrow states, deposit repay Vault into pool underlying vault and return any remaining Vault
        let scaledAccountTotalBorrowsNew = scaledAccountTotalBorrows > scaledRepayAmount ? scaledAccountTotalBorrows - scaledRepayAmount : (0 as UInt256)
        self.underlyingVault.deposit(from: <-repayUnderlyingVault)
        self.scaledTotalBorrows = self.scaledTotalBorrows - scaledActualRepayAmount
        emit Repay(borrower: borrower, scaledActualRepayAmount: scaledActualRepayAmount, scaledBorrowerTotalBorrows: scaledAccountTotalBorrowsNew, scaledPoolTotalBorrows: self.scaledTotalBorrows);
        if (scaledAccountTotalBorrows > scaledRepayAmount) {
            self.accountBorrows[borrower] = BorrowSnapshot(principal: scaledAccountTotalBorrowsNew, interestIndex: self.scaledBorrowIndex)
            return nil
        } else {
            self.accountBorrows.remove(key: borrower)
            let surplusAmount = Config.ScaledUInt256ToUFix64(scaledRepayAmount - scaledAccountTotalBorrows)
            return <- self.underlyingVault.withdraw(amount: surplusAmount)
        }
    }

    // User repays borrow with a underlying Vault and receives a new underlying Vault if there's still any remaining left.
    // Note that the borrower address can potentially not be the same as the repayer address (which means someone can repay on behave of borrower),
    // this is allowed as there's no safety issue to do so.
    pub fun repayBorrow(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.balance > 0.0:
                Config.ErrorEncode (
                    msg: "Repayed with empty underlying Vault",
                    err: Config.Error.EMPTY_INPUT_FUNGIBLETOKEN_VAULT
                )
            repayUnderlyingVault.isInstance(self.underlyingAssetType):
                Config.ErrorEncode (
                    msg: "Repayed vault and pool underlying type mismatch, revert",
                    err: Config.Error.MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
                )
        }
        // Accrues interests and checkpoints latest states
        self.accrueInterest()

        return <- self.repayBorrowInternal(borrower: borrower, repayUnderlyingVault: <-repayUnderlyingVault)
    }

    pub fun liquidate(
        liquidator: Address,
        borrower: Address,
        poolCollateralizedToSeize: Address,
        repayUnderlyingVault: @FungibleToken.Vault
    ): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.isInstance(self.underlyingAssetType):
                Config.ErrorEncode (
                    msg: "Liquidator repayed vault and pool underlying type mismatch, revert",
                    err: Config.Error.MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
                )
        }
        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Check whether or not liquidateAllowed()
        let scaledUnderlyingAmountToRepay = Config.UFix64ToScaledUInt256(repayUnderlyingVault.balance)

        self.comptrollerCap!.borrow()!.liquidateAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolBorrowed: self.poolAddress,
            poolCollateralized: poolCollateralizedToSeize,
            borrower: borrower,
            repayUnderlyingAmountScaled: scaledUnderlyingAmountToRepay
        )

        // 3. Liquidator repays on behave of borrower
        assert(liquidator != borrower, message:
            Config.ErrorEncode (
                msg: "Liquidator and borrower can not be the same person.",
                err: Config.Error.SAME_LIQUIDATOR_AND_BORROWER
            )
        )

        let remainingVault <- self.repayBorrowInternal(borrower: borrower, repayUnderlyingVault: <-repayUnderlyingVault)
        let scaledRemainingAmount = Config.UFix64ToScaledUInt256(remainingVault?.balance ?? 0.0)
        let scaledActualRepayAmount = scaledUnderlyingAmountToRepay - scaledRemainingAmount
        // Calculate collateralLpTokenSeizedAmount based on actualRepayAmount
        let scaledCollateralLpTokenSeizedAmount = self.comptrollerCap!.borrow()!.calculateCollateralPoolLpTokenToSeize(
            borrower: borrower,
            borrowPool: self.poolAddress,
            collateralPool: poolCollateralizedToSeize,
            actualRepaidBorrowAmountScaled: scaledActualRepayAmount
        )

        // 4. seizeInternal if current pool is also borrower's collateralPool; otherwise seize external collateralPool
        if (poolCollateralizedToSeize == self.poolAddress) {
            self.seizeInternal(
                borrowPool: self.poolAddress,
                liquidator: liquidator,
                borrower: borrower,
                scaledBorrowerLpTokenToSeize: scaledCollateralLpTokenSeizedAmount
            )
        } else {
            // Seize external
            let externalPoolPublicRef = getAccount(poolCollateralizedToSeize)
                .getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow() 
                    ?? panic(
                        Config.ErrorEncode (
                            msg: "Cannot borrow reference to external PoolPublic",
                            err: Config.Error.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
                        ) 
                    )
            externalPoolPublicRef.seize(
                seizerPoolCertificate: <- create PoolCertificate(),
                seizerPool: self.poolAddress,
                liquidator: liquidator,
                borrower: borrower,
                scaledBorrowerCollateralLpTokenToSeize: scaledCollateralLpTokenSeizedAmount
            )
        }

        emit Liquidate(
            liquidator: liquidator,
            borrower: borrower,
            scaledActualRepaidUnderlying: scaledActualRepayAmount,
            collateralPoolToSeize: poolCollateralizedToSeize,
            scaledCollateralPoolLpTokenSeized: scaledCollateralLpTokenSeizedAmount
        )
        return <-remainingVault
    }

    // Only used for "external" seize. Run-time type check of pool certificate ensures it can only be called by other pools of comptroller's markets.
    // @seizerPool: The external pool seizing the current collateral pool (i.e. borrowPool)
    pub fun seize(
        seizerPoolCertificate: @{Interfaces.IdentityCertificate},
        seizerPool: Address,
        liquidator: Address,
        borrower: Address,
        scaledBorrowerCollateralLpTokenToSeize: UInt256
    ) {
        pre {
            seizerPool != self.poolAddress:
                Config.ErrorEncode (
                    msg: "External seize only, seizerPool cannot be current",
                    err: Config.Error.CANNOT_CALL_EXTERNAL_SEIZE_POOLSELF
                )
        }
        // Check and verify caller from another LendingPool contract
        self.comptrollerCap!.borrow()!.poolCallerAllowed(
            callerCertificate: <- seizerPoolCertificate,
            callerAddress: seizerPool
        )

        // 2. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 3. seizeInternal
        self.seizeInternal(
            borrowPool: seizerPool,
            liquidator: liquidator,
            borrower: borrower,
            scaledBorrowerLpTokenToSeize: scaledBorrowerCollateralLpTokenToSeize
        )
    }

    // Caller ensures accrueInterest() has been called
    access(self) fun seizeInternal(
        borrowPool: Address,
        liquidator: Address,
        borrower: Address,
        scaledBorrowerLpTokenToSeize: UInt256
    ) {
        pre {
            liquidator != borrower:
                Config.ErrorEncode (
                    msg: "seize: liquidator is borrower, revert",
                    err: Config.Error.SAME_LIQUIDATOR_AND_BORROWER
                )
        }
        
        self.comptrollerCap!.borrow()!.seizeAllowed(
            poolCertificate: <- create PoolCertificate(),
            borrowPool: borrowPool,
            collateralPool: self.poolAddress,
            liquidator: liquidator,
            borrower: borrower,
            seizeCollateralPoolLpTokenAmountScaled: scaledBorrowerLpTokenToSeize
        )

        // accountLpTokens[borrower] -= collateralPoolLpTokenToSeize
        // LendingPool.totalReserves += collateralPoolLpTokenToSeize * LendingPool.poolSeizeShare
        // accountLpTokens[liquidator] += (collateralPoolLpTokenToSeize * (1 - LendingPool.poolSeizeShare))
        let scaleFactor = Config.scaleFactor
        let scaledProtocolSeizedLpTokens = scaledBorrowerLpTokenToSeize * self.scaledPoolSeizeShare / scaleFactor
        let scaledLiquidatorSeizedLpTokens = scaledBorrowerLpTokenToSeize - scaledProtocolSeizedLpTokens
        let scaledUnderlyingToLpTokenRate = self.underlyingToLpTokenRateSnapshotScaled()
        let scaledAddedUnderlyingReserves = scaledUnderlyingToLpTokenRate * scaledProtocolSeizedLpTokens / scaleFactor
        self.scaledTotalReserves = self.scaledTotalReserves + scaledAddedUnderlyingReserves
        self.scaledTotalSupply = self.scaledTotalSupply - scaledProtocolSeizedLpTokens
        // in-place liquidation: only virtual lpToken records get updated, no token deposit / withdraw needs to happen
        if (self.accountLpTokens[borrower] == scaledBorrowerLpTokenToSeize) {
            self.accountLpTokens.remove(key: borrower)
        } else {
            self.accountLpTokens[borrower] = self.accountLpTokens[borrower]! - scaledBorrowerLpTokenToSeize
        }
        self.accountLpTokens[liquidator] = scaledLiquidatorSeizedLpTokens + (self.accountLpTokens[liquidator] ?? (0 as UInt256))

        emit ReservesAdded(donator: self.poolAddress, scaledAddedUnderlyingAmount: scaledAddedUnderlyingReserves, scaledNewTotalReserves: self.scaledTotalReserves)
    }

    pub resource PoolCertificate: Interfaces.IdentityCertificate {}

    pub resource PoolPublic: Interfaces.PoolPublic {
        pub fun getPoolAddress(): Address {
            return LendingPool.poolAddress
        }
        pub fun getUnderlyingTypeString(): String {
            let underlyingType = LendingPool.getUnderlyingAssetType()
            // "A.1654653399040a61.FlowToken.Vault" => "FlowToken"
            return underlyingType.slice(from: 19, upTo: underlyingType.length - 6)
        }
        pub fun getUnderlyingToLpTokenRateScaled(): UInt256 {
            return LendingPool.underlyingToLpTokenRateSnapshotScaled()
        }
        pub fun getAccountLpTokenBalanceScaled(account: Address): UInt256 {
            return LendingPool.accountLpTokens[account] ?? (0 as UInt256)
        }
        pub fun getAccountBorrowBalanceScaled(account: Address): UInt256 {
            return LendingPool.borrowBalanceSnapshotScaled(borrowerAddress: account)
        }
        pub fun getAccountBorrowPrincipalSnapshotScaled(account: Address): UInt256 {
            if (LendingPool.accountBorrows.containsKey(account) == false) {
                return 0
            } else {
                return LendingPool.accountBorrows[account]!.scaledPrincipal
            }
        }
        pub fun getAccountBorrowIndexSnapshotScaled(account: Address): UInt256 {
            if (LendingPool.accountBorrows.containsKey(account) == false) {
                return 0
            } else {
                return LendingPool.accountBorrows[account]!.scaledInterestIndex
            }
        }
        pub fun getAccountSnapshotScaled(account: Address): [UInt256; 5] {
            return [
                self.getUnderlyingToLpTokenRateScaled(),
                self.getAccountLpTokenBalanceScaled(account: account),
                self.getAccountBorrowBalanceScaled(account: account),
                self.getAccountBorrowPrincipalSnapshotScaled(account: account),
                self.getAccountBorrowIndexSnapshotScaled(account: account)
            ]
        }
        pub fun getPoolReserveFactorScaled(): UInt256 {
            return LendingPool.scaledReserveFactor
        }
        pub fun getInterestRateModelAddress(): Address {
            return LendingPool.interestRateModelAddress!
        }
        pub fun getPoolTotalBorrowsScaled(): UInt256 {
            return LendingPool.scaledTotalBorrows
        }
        pub fun getPoolTotalSupplyScaled(): UInt256 {
            return LendingPool.getPoolCash() + LendingPool.scaledTotalBorrows
        }
        pub fun getPoolTotalReservesScaled(): UInt256 {
            return LendingPool.scaledTotalReserves
        }
        pub fun getPoolSupplierCount(): UInt256 {
            return UInt256(LendingPool.accountLpTokens.length)
        }
        pub fun getPoolBorrowerCount(): UInt256 {
            return UInt256(LendingPool.accountBorrows.length)
        }
        pub fun getPoolSupplierList(): [Address] {
            return LendingPool.accountLpTokens.keys
        }
        pub fun getPoolSupplierSlicedList(from: UInt64, to: UInt64): [Address] {
            pre {
                from <= to && to < UInt64(LendingPool.accountLpTokens.length):
                    Config.ErrorEncode (
                        msg: "Index out of range",
                        err: Config.Error.LIST_OUT_OF_RANGE
                    )
            }
            let borrowers: &[Address] = &LendingPool.accountLpTokens.keys as &[Address]
            let list: [Address] = []
            var i = from
            while i <= to {
                list.append(borrowers[i])
                i = i + 1
            }
            return list
        }
        pub fun getPoolBorrowerList(): [Address] {
            return LendingPool.accountBorrows.keys
        }
        pub fun getPoolBorrowerSlicedList(from: UInt64, to: UInt64): [Address] {
            pre {
                from <= to && to < UInt64(LendingPool.accountBorrows.length):
                    Config.ErrorEncode (
                        msg: "Index out of range",
                        err: Config.Error.LIST_OUT_OF_RANGE
                    )
            }
            let borrowers: &[Address] = &LendingPool.accountBorrows.keys as &[Address]
            let list: [Address] = []
            var i = from
            while i <= to {
                list.append(borrowers[i])
                i = i + 1
            }
            return list
        }
        pub fun getPoolBorrowAprScaled(): UInt256 {
            let scaledBorrowRatePerBlock =
                LendingPool.interestRateModelCap!.borrow()!.getBorrowRate(
                    cash: LendingPool.getPoolCash(),
                    borrows: LendingPool.scaledTotalBorrows,
                    reserves: LendingPool.scaledTotalReserves
                )
            let blocksPerYear = LendingPool.interestRateModelCap!.borrow()!.getBlocksPerYear()
            return scaledBorrowRatePerBlock * blocksPerYear
        }
        pub fun getPoolSupplyAprScaled(): UInt256 {
            let scaledSupplyRatePerBlock =
                LendingPool.interestRateModelCap!.borrow()!.getSupplyRate(
                    cash: LendingPool.getPoolCash(),
                    borrows: LendingPool.scaledTotalBorrows,
                    reserves: LendingPool.scaledTotalReserves,
                    reserveFactor: LendingPool.scaledReserveFactor
                )
            let blocksPerYear = LendingPool.interestRateModelCap!.borrow()!.getBlocksPerYear()
            return scaledSupplyRatePerBlock * blocksPerYear
        }
        pub fun accrueInterest() {
            let ret = LendingPool.accrueInterest()
        }
        pub fun getPoolCertificateType(): Type {
            return Type<@LendingPool.PoolCertificate>()
        }
        pub fun seize(
            seizerPoolCertificate: @{Interfaces.IdentityCertificate},
            seizerPool: Address,
            liquidator: Address,
            borrower: Address,
            scaledBorrowerCollateralLpTokenToSeize: UInt256
        ) {
            LendingPool.seize(
                seizerPoolCertificate: <- seizerPoolCertificate,
                seizerPool: seizerPool,
                liquidator: liquidator,
                borrower: borrower,
                scaledBorrowerCollateralLpTokenToSeize: scaledBorrowerCollateralLpTokenToSeize
            )
        }
    }

    pub resource PoolAdmin {
        // Admin function to call accrueInterest() to checkpoint latest states, and then update the interest rate model
        pub fun setInterestRateModel(newInterestRateModelAddress: Address) {
            LendingPool.accrueInterest()
            
            if (newInterestRateModelAddress != LendingPool.interestRateModelAddress) {
                let oldInterestRateModelAddress = LendingPool.interestRateModelAddress
                LendingPool.interestRateModelAddress = newInterestRateModelAddress
                LendingPool.interestRateModelCap = getAccount(newInterestRateModelAddress)
                    .getCapability<&{Interfaces.InterestRateModelPublic}>(Config.InterestRateModelPublicPath)
                emit NewInterestRateModel(oldInterestRateModelAddress, newInterestRateModelAddress)
            }
            return
        }

        // Admin function to call accrueInterest() to checkpoint latest states, and then update reserveFactor
        pub fun setReserveFactor(newReserveFactor: UFix64) {
            pre {
                newReserveFactor <= 1.0:
                Config.ErrorEncode (
                    msg: "Reserve factor should be less than 1.0.",
                    err: Config.Error.SET_RESERVE_FACTOR_OUT_OF_RANGE
                )
            }
            LendingPool.accrueInterest()
            
            let oldReserveFactor = Config.ScaledUInt256ToUFix64(LendingPool.scaledReserveFactor)
            LendingPool.scaledReserveFactor = Config.UFix64ToScaledUInt256(newReserveFactor)

            emit NewReserveFactor(oldReserveFactor, newReserveFactor);
            return
        }

        // Admin function to update poolSeizeShare
        pub fun setPoolSeizeShare(newPoolSeizeShare: UFix64) {
            pre {
                newPoolSeizeShare <= 1.0:
                Config.ErrorEncode (
                    msg: "Pool seize share factor should be less than 1.0.",
                    err: Config.Error.SET_POOL_SEIZE_SHARE_OUT_OF_RANGE
                )
            }
            let oldPoolSeizeShare = Config.ScaledUInt256ToUFix64(LendingPool.scaledPoolSeizeShare)
            LendingPool.scaledPoolSeizeShare = Config.UFix64ToScaledUInt256(newPoolSeizeShare)

            emit NewPoolSeizeShare(oldPoolSeizeShare, newPoolSeizeShare);
            return
        }

        // Admin function to set comptroller
        pub fun setComptroller(newComptrollerAddress: Address) {
            post {
                LendingPool.comptrollerCap != nil && LendingPool.comptrollerCap!.check() == true:
                    Config.ErrorEncode (
                        msg: "Set new Comptroller fail.",
                        err: Config.Error.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
                    )
            }
            
            if (newComptrollerAddress != LendingPool.comptrollerAddress) {
                let oldComptrollerAddress = LendingPool.comptrollerAddress
                LendingPool.comptrollerAddress = newComptrollerAddress
                LendingPool.comptrollerCap = getAccount(newComptrollerAddress)
                    .getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath)
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
                LendingPool.accrualBlockNumber == 0 && LendingPool.scaledBorrowIndex == 0:
                    Config.ErrorEncode (
                        msg: "Pool can only be initialized once",
                        err: Config.Error.DUPLICATED_INITIALIZATION
                    )
                reserveFactor <= 1.0 && poolSeizeShare <= 1.0:
                    Config.ErrorEncode (
                        msg: "ReserveFactor | poolSeizeShare out of range 1.0",
                        err: Config.Error.INVALID_PARAMETERS
                    )
            }
            post {
                LendingPool.interestRateModelCap != nil && LendingPool.interestRateModelCap!.check() == true:
                    Config.ErrorEncode (
                        msg: "InterestRateModel not properly initialized",
                        err: Config.Error.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
                    )
            }
            LendingPool.accrualBlockNumber = UInt256(getCurrentBlock().height)
            LendingPool.scaledBorrowIndex = Config.scaleFactor
            LendingPool.scaledReserveFactor = Config.UFix64ToScaledUInt256(reserveFactor)
            LendingPool.scaledPoolSeizeShare = Config.UFix64ToScaledUInt256(poolSeizeShare)
            LendingPool.interestRateModelAddress = interestRateModelAddress
            LendingPool.interestRateModelCap = getAccount(interestRateModelAddress)
                .getCapability<&{Interfaces.InterestRateModelPublic}>(Config.InterestRateModelPublicPath)
        }

        // Admin function to withdraw pool reserve
        pub fun withdrawReserves(reduceAmount: UFix64): @FungibleToken.Vault {
            LendingPool.accrueInterest()
            
            let reduceAmountScaled = reduceAmount == UFix64.max ? LendingPool.scaledTotalReserves : Config.UFix64ToScaledUInt256(reduceAmount)
            assert(reduceAmountScaled <= LendingPool.scaledTotalReserves, message:
                Config.ErrorEncode (
                    msg: "Exceed pool reserve amount",
                    err: Config.Error.EXCEED_TOTAL_RESERVES
                )
            )
            assert(reduceAmountScaled <= LendingPool.getPoolCash(), message:
                Config.ErrorEncode (
                    msg: "Exceed pool liquidity",
                    err: Config.Error.INSUFFICIENT_POOL_LIQUIDITY
                )
            )
            LendingPool.scaledTotalReserves = LendingPool.scaledTotalReserves - reduceAmountScaled
            
            emit ReservesReduced(scaledReduceAmount: reduceAmountScaled, scaledNewTotalReserves: LendingPool.scaledTotalReserves)

            return <- LendingPool.underlyingVault.withdraw(amount: reduceAmount)
        }
    }

    init() {
        self.PoolAdminStoragePath = /storage/poolAdmin
        self.UnderlyingAssetVaultStoragePath = /storage/poolUnderlyingAssetVault
        self.PoolPublicStoragePath = /storage/poolPublic
        self.PoolPublicPublicPath = /public/poolPublic

        self.poolAddress = self.account.address
        self.scaledInitialExchangeRate = Config.scaleFactor
        self.accrualBlockNumber = 0
        self.scaledBorrowIndex = 0
        self.scaledTotalBorrows = 0
        self.scaledTotalReserves = 0
        self.scaledReserveFactor = 0
        self.scaledPoolSeizeShare = 0
        self.scaledTotalSupply = 0
        self.accountLpTokens = {}
        self.accountBorrows = {}
        self.interestRateModelAddress = nil
        self.interestRateModelCap = nil
        self.comptrollerAddress = nil
        self.comptrollerCap = nil
        self.underlyingVault <- self.account.load<@FungibleToken.Vault>(from: self.UnderlyingAssetVaultStoragePath)
            ?? panic("Deployer should own zero-balanced underlying asset vault first")
        self.underlyingAssetType = self.underlyingVault.getType()
        assert(self.underlyingVault.balance == 0.0, message: "Must initialize pool with zero-balanced underlying asset vault")

        // save pool admin
        destroy <-self.account.load<@AnyResource>(from: self.PoolAdminStoragePath)
        self.account.save(<-create PoolAdmin(), to: self.PoolAdminStoragePath)
        // save pool public interface
        self.account.unlink(self.PoolPublicPublicPath)
        destroy <-self.account.load<@AnyResource>(from: self.PoolPublicStoragePath)
        self.account.save(<-create PoolPublic(), to: self.PoolPublicStoragePath)
        self.account.link<&{Interfaces.PoolPublic}>(self.PoolPublicPublicPath, target: self.PoolPublicStoragePath)
    }
}