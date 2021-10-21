import FungibleToken from "./FungibleToken.cdc"
import Interfaces from "./Interfaces.cdc"
import TwoSegmentsInterestRateModel from "./TwoSegmentsInterestRateModel.cdc"
import ComptrollerV1 from "./ComptrollerV1.cdc"


/**

PoolToken is a Contract-based Fungible Token, which also conforms to the
FungibleToken interface. However, it also uses central ledger (smart contract) to record
vault's balance, and the contract-recorded balance serves as "ultimate truth".

Contract-based Fungible Token is used when peer-to-peer style FungibleToken is not enough, where a centralized
ledger (i.e. smart contract) is necessary to record globally shared states and used as underlying truth.

*/

pub contract PoolToken: FungibleToken {
    pub let PoolAdminStoragePath: StoragePath
    pub let UnderlyingAssetVaultStoragePath: StoragePath
    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath

    pub enum Error: UInt8 {
        pub case NO_ERROR
        pub case CURRENT_INTEREST_RATE_MODEL_NULL
        pub case SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED
        pub case SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED
        pub case SET_RESERVE_FACTOR_OUT_OF_RANGE
        pub case SET_POOL_SEIZE_SHARE_OUT_OF_RANGE
    }

    // Account address the pool is deployed to
    pub let address: Address
    // Initial exchange rate used when minting the first PoolToken (when PoolToken.totalSupply == 0)
    pub let initialExchangeRate: UFix64
    // Block number that interest was last accrued at
    pub var accrualBlockNumber: UInt64
    // Accumulator of the total earned interest rate since the opening of the market
    pub var borrowIndex: UFix64
    // Total amount of outstanding borrows of the underlying in this market
    pub var totalBorrows: UFix64
    // Total amount of reserves of the underlying held in this market
    pub var totalReserves: UFix64
    // Total number of pool tokens in circulation
    pub var totalSupply: UFix64
    // Fraction of generated interest added to protocol reserves.
    // Must be in [0.0, 1.0]
    pub var reserveFactor: UFix64
    // Share of seized collateral that is added to reserves when liquidation happenes, e.g. 0.028.
    // Must be in [0.0, 1.0]
    pub var poolSeizeShare: UFix64
    // { PoolToken.Vault.uuid => balance }
    // This dictionary acts as the centralized records and ultimate truth of PoolToken.Vault balance
    access(contract) let balances: {UInt64: UFix64}

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
    pub var interestRateModelRef: Capability<&{Interfaces.InterestRateModelPublic}>?
    pub var comptrollerAddress: Address?
    pub var comptrollerRef: Capability<&{Interfaces.ComptrollerPublic}>?
    // Save underlying asset deposited into this pool
    access(self) var underlyingVault: @FungibleToken.Vault

    // TokensInitialized
    // The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)
    // TokensWithdrawn
    // The event that is emitted when PoolTokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    // TokensDeposited
    // The event that is emitted when PoolTokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)
    // TokensMinted
    // The event that is emitted when new PoolTokens are minted
    pub event TokensMinted(amount: UFix64)
    // Event emitted when there's a difference between contract-based data and vault-based data
    pub event TokensDiff(faultVaultId: UInt64, vaultData: UFix64, contractData: UFix64, owner: Address?)
    // Event emitted when interest is accrued
    pub event AccrueInterest(_ cashPrior: UFix64, _ interestAccumulated: UFix64, _ borrowIndexNew: UFix64, _ totalBorrowsNew: UFix64)
    // Event emitted when underlying asset is deposited into pool
    pub event Supply(suppliedUnderlyingAmount: UFix64, mintedPoolTokenAmount: UFix64)
    // Event emitted when PoolToken is returned and redeemed for underlying asset
    pub event Redeem(returnedPoolTokenAmount: UFix64, actualRedeemedPoolToken: UFix64, redeemedUnderlyingAmount: UFix64)
    // Event emitted when user borrows underlying from the pool
    pub event Borrow(borrower: Address, borrowAmount: UFix64, borrowerTotalBorrows: UFix64, poolTotalBorrows: UFix64);
    // Event emitted when user repays underlying to pool
    pub event Repay(borrower: Address, actualRepayAmount: UFix64, borrowerTotalBorrows: UFix64, poolTotalBorrows: UFix64)
    // Event emitted when interestRateModel is changed
    pub event NewInterestRateModel(_ oldInterestRateModelAddress: Address?, _ newInterestRateModelAddress: Address)
    // Event emitted when the reserveFactor is changed
    pub event NewReserveFactor(_ oldReserveFactor: UFix64, _ newReserveFactor: UFix64)
    // Event emitted when the poolSeizeShare is changed
    pub event NewPoolSeizeShare(_ oldPoolSeizeShare: UFix64, _ newPoolSeizeShare: UFix64)
    // Event emitted when the comptroller is changed
    pub event NewComptroller(_ oldComptrollerAddress: Address?, _ newComptrollerAddress: Address)

    // Return balance given the resource uuid of a PoolToken.Vault.
    // Return 0.0 if no such vault exists.
    pub fun getBalance(vaultId: UInt64): UFix64 {
        if (self.balances.containsKey(vaultId) == false) {
            return 0.0
        }
        return self.balances[vaultId]!
    }

    // Return underlying asset's type of current pool
    pub fun getUnderlyingAssetType(): String {
        return self.underlyingVault.getType().identifier
    }

    // Gets current underlying balance of this pool
    pub fun getPoolCash(): UFix64 {
        return self.underlyingVault.balance
    }

    // The resource that contains the functions to send and receive tokens while still 
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {
        pub var balance: UFix64

        // The conforming type must declare an initializer that allows prioviding the initial balance of the Vault
        init(balance: UFix64) {
          self.balance = balance
          PoolToken.balances[self.uuid] = balance
        }

        // withdraw subtracts `amount` from the Vault's balance and returns a new Vault with the subtracted balance
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            post {
                PoolToken.getBalance(vaultId: self.uuid) == before(PoolToken.getBalance(vaultId: self.uuid)) - amount:
                    "Contract-based Vault balance must be the difference of the previous record and the withdrawn amount"
                PoolToken.getBalance(vaultId: self.uuid) == self.balance:
                    "Vault balance must match with contract-based balance after withdraw"
            }

            PoolToken.balances[self.uuid] = PoolToken.balances[self.uuid]! - amount
            self.balance = PoolToken.balances[self.uuid]!
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <- create Vault(balance: amount)
        }

        // deposit takes a Vault and adds its contract-based balance to the balance of this Vault
        // Note: this also checks and syncs vault-based data with contract-based data if there's mismatch found for the deposited vault,
        // and emits `TokensDiff` event
        pub fun deposit(from: @FungibleToken.Vault) {
            post {
                PoolToken.getBalance(vaultId: self.uuid) == before(PoolToken.getBalance(vaultId: self.uuid)) + before(PoolToken.getBalance(vaultId: from.uuid)):
                    "Contract-based vault balance must be the sum of the previous record and the deposited one"
                PoolToken.getBalance(vaultId: self.uuid) == self.balance:
                    "Vault balance must match with contract-based balance after deposit"
            }

            let vault <- from as! @PoolToken.Vault
            if (PoolToken.getBalance(vaultId: vault.uuid) != vault.balance) {
                let oldBalance = vault.balance
                // Sync balance using contract-based data
                vault.balance = PoolToken.getBalance(vaultId: vault.uuid)
                emit TokensDiff(faultVaultId: vault.uuid, vaultData: oldBalance, contractData: vault.balance, owner: vault.owner?.address)
            }
            self.balance = self.balance + vault.balance
            PoolToken.balances[self.uuid] = PoolToken.balances[self.uuid]! + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
          PoolToken.totalSupply = PoolToken.totalSupply - self.balance
          PoolToken.balances.remove(key: self.uuid)
        }
    }
    
    pub fun createEmptyVault(): @PoolToken.Vault {
        return <- create Vault(balance: 0.0)
    }

    access(self) fun mintPoolTokens(amount: UFix64): @PoolToken.Vault {
        pre {
            amount > 0.0: "Amount minted must be greater than zero"
        }
        self.totalSupply = self.totalSupply + amount
        emit TokensMinted(amount: amount)
        return <- create Vault(balance: amount)
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

        if (self.interestRateModelRef == nil || self.interestRateModelRef!.check() == false) {
            return Error.CURRENT_INTEREST_RATE_MODEL_NULL
        }
        // Get the borrow interest rate per block
        let borrowRatePerBlock =
            self.interestRateModelRef!.borrow()!.getBorrowRate(cash: cashPrior, borrows: borrowPrior, reserves: reservesPrior)
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

    // Calculates the exchange rate from the underlying to PoolToken (i.e. ? UnderlyingToken per 1 PoolToken)
    // Note: This is for internal call only, it doesn't call accrueInterest() first to update with latest states which is 
    // used in calculating the exchange rate.
    access(self) fun underlyingToPoolTokenRateSnapshot(): UFix64 {
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

    // User deposits underlying asset's Vault into the pool and receives PoolToken.Vault
    // TODO: Check fake currency deposit? 
    pub fun supply(inUnderlyingVault: @FungibleToken.Vault): @PoolToken.Vault {
        pre {
            inUnderlyingVault.balance > 0.0: "Supplied empty underlying Vault"
        }
        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "SUPPLY_ACCRUE_INTEREST_FAILED")

        // 2. Check whether or not supplyAllowed()
        ///// TODO: switch 1. and 2. 
        let amount = inUnderlyingVault.balance
        let ret = self.comptrollerRef!.borrow()!.supplyAllowed(poolAddress: self.address, supplyUnderlyingAmount: amount)
        assert(ret == 0, message: "supply not allowed, error reason: ".concat(ret.toString()))

        // 3. Deposit into underlying vault and mint corresponding PoolTokens 
        let underlyingToken2PoolTokenRate = self.underlyingToPoolTokenRateSnapshot()
        let mintAmount = amount / underlyingToken2PoolTokenRate

        emit Supply(suppliedUnderlyingAmount: amount, mintedPoolTokenAmount: mintAmount);
        self.underlyingVault.deposit(from: <-inUnderlyingVault)
        return <- self.mintPoolTokens(amount: mintAmount)
    }

    // User redeems PoolToken.Vault for the underlying asset's vault
    // Since redeemer would decrease his overall collateral ratio across all markets, he has to give proof of all the markets
    // he has provided liquidity to, in order to pass the check.
    pub fun redeem(
        redeemer: Address
        redeemerCollaterals: [&FungibleToken.Vault]
        poolTokenVault: @PoolToken.Vault,
    ): @FungibleToken.Vault {
        pre {
            poolTokenVault.balance > 0.0: "Redeemed empty PoolToken Vault"
        }
        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "REDEEM_ACCRUE_INTEREST_FAILED")

        // 2. Check whether or not redeemAllowed()
        ///// TODO: switch 1. and 2. 
        // Note: Use contract-based balance instead of passed-in balance for security considerations
        let contractBasedPoolTokenAmount = self.getBalance(vaultId: poolTokenVault.uuid)
        let ret = self.comptrollerRef!.borrow()!.redeemAllowed(
            poolAddress: self.address,
            redeemerAddress: redeemer,
            redeemerCollaterals: redeemerCollaterals,
            redeemPoolTokenAmount: contractBasedPoolTokenAmount
        )
        assert(ret == 0, message: "redeem not allowed, error reason: ".concat(ret.toString()))

        // 3. Burn corresponding PoolTokens, withdraw from underlying vault and return it
        let redeemedUnderlyingAmount = contractBasedPoolTokenAmount * self.underlyingToPoolTokenRateSnapshot()
        assert(redeemedUnderlyingAmount <= self.getPoolCash(), message: "REDEEM_FAILED_NOT_ENOUGH_UNDERLYING_BALANCE")
        // 
        if (contractBasedPoolTokenAmount != poolTokenVault.balance) {
            // Emits `TokensDiff` event
            emit TokensDiff(
                faultVaultId: poolTokenVault.uuid,
                vaultData: poolTokenVault.balance,
                contractData: contractBasedPoolTokenAmount,
                owner: poolTokenVault.owner?.address
            )
        }
        emit Redeem(
            returnedPoolTokenAmount: poolTokenVault.balance,
            actualRedeemedPoolToken: contractBasedPoolTokenAmount,
            redeemedUnderlyingAmount: redeemedUnderlyingAmount
        )
        destroy poolTokenVault
        return <- self.underlyingVault.withdraw(amount: redeemedUnderlyingAmount)
    }

    access(self) fun borrowerCapabilityCheck(
        borrower: Address,
        borrowerCollaterals: [&FungibleToken.Vault]
    ): Bool {
        if (borrowerCollaterals.length == 0) {
            return false
        }
        for collateral in borrowerCollaterals {
            if (collateral.owner!.address != borrower) {
                return false
            }
        }
        return true
    }

    // User borrows underlying asset from the pool.
    // Since borrower would decrease his overall collateral ratio across all markets, he has to give proof of all the markets
    // he has provided liquidity to, in order to pass the check.
    // Note that: *Must* pass in capability array to PoolToken.Vault (i.e. all of the markets the borrower has deposited liquidity to)
    // to verify against borrowerAddress argument, so that it cannot be faked (i.e. if borrowerAddress != tx.Authorizer),
    // since Capability<&PoolToken.Vault> array can only be given by the owner of PoolTolen.Vault.
    pub fun borrow(
        borrower: Address,
        borrowAmount: UFix64,
        borrowerCollaterals: [&FungibleToken.Vault]
    ): @FungibleToken.Vault {
        pre {
            borrowAmount > 0.0: "borrowAmount zero"
            borrowAmount <= self.getPoolCash(): "Pool not enough underlying balance for borrow"
            self.borrowerCapabilityCheck(borrower: borrower, borrowerCollaterals: borrowerCollaterals):
                "borrowerAddress doesn't match with [capability of collaterals] array"
        }
        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "BORROW_ACCRUE_INTEREST_FAILED")

        ///// 2. TODO: Check comptroller.borrowAllowed()

        // 3. Updates borrow states, withdraw from pool underlying vault and deposits into borrower's account
        self.totalBorrows = self.totalBorrows + borrowAmount
        let borrowBalanceNew = borrowAmount + self.borrowBalanceSnapshot(borrowerAddress: borrower)
        self.accountBorrows[borrower] = BorrowSnapshot(principal: borrowBalanceNew, interestIndex: self.borrowIndex)
        emit Borrow(borrower: borrower, borrowAmount: borrowAmount, borrowerTotalBorrows: borrowBalanceNew, poolTotalBorrows: self.totalBorrows);
        return <- self.underlyingVault.withdraw(amount: borrowAmount)
    }

    // User repays borrows with a underlying Vault and receives a new underlying Vault if there's still any remaining left.
    // Note that the borrower address can potentially be faked (which means borrowerAddr != repayTx.Authorizer), 
    // but there's no incentive for tx.authorizer to do so.
    pub fun repayBorrow(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.balance > 0.0: "repayed with empty underlying Vault"
        }
        // 1. Accrues interests and checkpoints latest states
        let err = self.accrueInterest()
        assert(err == Error.NO_ERROR, message: "REPAY_BORROW_ACCRUE_INTEREST_FAILED")

        ///// 2. TODO: Check comptroller.repayAllowed()

        // 3. Updates borrow states, deposit repay Vault into pool underlying vault and return any remaining Vault
        let repayAmount = repayUnderlyingVault.balance
        let accountTotalBorrows = self.borrowBalanceSnapshot(borrowerAddress: borrower)
        let actualRepayAmount = accountTotalBorrows > repayAmount ? repayAmount : accountTotalBorrows
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

    pub resource PoolPublic: Interfaces.PoolPublic {
        pub fun getPoolAddress(): Address {
            return PoolToken.address
        }
        pub fun getPoolTypeString(): String {
            return PoolToken.getType().identifier
        }
        pub fun getUnderlyingTypeString(): String {
            return PoolToken.getUnderlyingAssetType()
        }
        pub fun getContractBasedVaultBalance(vaultId: UInt64): UFix64 {
            return PoolToken.getBalance(vaultId: vaultId)
        }
        pub fun getUnderlyingToPoolTokenRateCurrent(): UFix64 {
            return PoolToken.underlyingToPoolTokenRateSnapshot()
        }
        pub fun getAccountBorrowsCurrent(account: Address): UFix64 {
            return PoolToken.borrowBalanceSnapshot(borrowerAddress: account)
        }
        pub fun getPoolTotalBorrows(): UFix64 {
            return PoolToken.totalBorrows
        }
    }

    pub resource PoolAdmin {
        // Admin function to call accrueInterest() to checkpoint latest states, and then update the interest rate model
        pub fun setInterestRateModel(newInterestRateModelAddress: Address): Error {
            let err = PoolToken.accrueInterest()
            if (err != Error.NO_ERROR) {
                return Error.SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED
            }
            if (newInterestRateModelAddress != PoolToken.interestRateModelAddress) {
                let oldInterestRateModelAddress = PoolToken.interestRateModelAddress
                PoolToken.interestRateModelAddress = newInterestRateModelAddress
                PoolToken.interestRateModelRef = getAccount(newInterestRateModelAddress)
                    .getCapability<&{Interfaces.InterestRateModelPublic}>(TwoSegmentsInterestRateModel.InterestRateModelPublicPath)
                emit NewInterestRateModel(oldInterestRateModelAddress, newInterestRateModelAddress)
            }
            return Error.NO_ERROR
        }

        // Admin function to call accrueInterest() to checkpoint latest states, and then update reserveFactor
        pub fun setReserveFactor(newReserveFactor: UFix64): Error {
            let err = PoolToken.accrueInterest()
            if (err != Error.NO_ERROR) {
                return Error.SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED
            }
            if (newReserveFactor > 1.0) {
                return Error.SET_RESERVE_FACTOR_OUT_OF_RANGE
            }
            let oldReserveFactor = PoolToken.reserveFactor
            PoolToken.reserveFactor = newReserveFactor
            emit NewReserveFactor(oldReserveFactor, newReserveFactor);
            return Error.NO_ERROR
        }

        // Admin function to update poolSeizeShare
        pub fun setPoolSeizeShare(newPoolSeizeShare: UFix64): Error {
            if (newPoolSeizeShare > 1.0) {
                return Error.SET_POOL_SEIZE_SHARE_OUT_OF_RANGE
            }
            let oldPoolSeizeShare = PoolToken.poolSeizeShare
            PoolToken.poolSeizeShare = newPoolSeizeShare
            emit NewPoolSeizeShare(oldPoolSeizeShare, newPoolSeizeShare);
            return Error.NO_ERROR
        }

        // Admin function to set comptroller
        pub fun setComptroller(newComptrollerAddress: Address) {
            if (newComptrollerAddress != PoolToken.comptrollerAddress) {
                let oldComptrollerAddress = PoolToken.comptrollerAddress
                PoolToken.comptrollerAddress = newComptrollerAddress
                PoolToken.comptrollerRef = getAccount(newComptrollerAddress)
                    .getCapability<&{Interfaces.ComptrollerPublic}>(ComptrollerV1.ComptrollerPublicPath)
                emit NewComptroller(oldComptrollerAddress, newComptrollerAddress)
            }
        }

        // Admin function to initialize pool.
        // Note: can be called only once
        pub fun initializePool(
            reserveFactor: UFix64,
            poolSeizeShare: UFix64,
            interestRateModelAddress: Address,
            underlyingAssetType: Type
            underlyingAssetVault: @FungibleToken.Vault
        ) {
            pre {
                PoolToken.accrualBlockNumber == 0 && PoolToken.borrowIndex == 0.0: "Pool can only be initialized once"
                reserveFactor <= 1.0 && poolSeizeShare <= 1.0: "reserveFactor | poolSeizeShare out of range 1.0"
                underlyingAssetVault.isInstance(underlyingAssetType): "cannot initialize pool with incompatible underlying type"
                underlyingAssetVault.balance == 0.0: "must initialize pool with zero-balanced underlying asset vault"
            }
            post {
                PoolToken.interestRateModelRef != nil && PoolToken.interestRateModelRef!.check() == true: "InterestRateModel not properly initialized"
            }
            PoolToken.accrualBlockNumber = getCurrentBlock().height
            PoolToken.borrowIndex = 1.0
            PoolToken.reserveFactor = reserveFactor
            PoolToken.poolSeizeShare = poolSeizeShare
            PoolToken.interestRateModelAddress = interestRateModelAddress     
            PoolToken.interestRateModelRef = getAccount(interestRateModelAddress)
                .getCapability<&{Interfaces.InterestRateModelPublic}>(TwoSegmentsInterestRateModel.InterestRateModelPublicPath)
            let tempVault <- PoolToken.underlyingVault <- underlyingAssetVault
            destroy tempVault
        }
    }

    init() {
        self.PoolAdminStoragePath = /storage/poolAdmin
        self.UnderlyingAssetVaultStoragePath = /storage/poolUnderlyingAssetVault
        self.VaultStoragePath = /storage/poolTokenVault
        self.ReceiverPublicPath = /public/poolTokenReceiver
        self.BalancePublicPath = /public/poolTokenBalance

        self.address = self.account.address
        self.initialExchangeRate = 1.0
        self.accrualBlockNumber = 0
        self.borrowIndex = 0.0
        self.totalBorrows = 0.0
        self.totalReserves = 0.0
        self.reserveFactor = 0.0
        self.poolSeizeShare = 0.0
        self.totalSupply = 0.0
        self.balances = {}
        self.accountBorrows = {}
        self.interestRateModelAddress = nil
        self.interestRateModelRef = nil
        self.comptrollerAddress = nil
        self.comptrollerRef = nil
        self.underlyingVault <- PoolToken.createEmptyVault()
        self.account.save(<-create PoolAdmin(), to: self.PoolAdminStoragePath)

        emit TokensInitialized(initialSupply: 0.0)
    }
}