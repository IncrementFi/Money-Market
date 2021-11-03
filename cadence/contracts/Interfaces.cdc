import FungibleToken from "./FungibleToken.cdc"

// Interface definitions all-in-one
pub contract interface Interfaces {
    pub resource interface InterestRateModelPublic {
        // exposing model specific fields, e.g.: modelName, model params.
        pub fun getInterestRateModelParams(): {String: AnyStruct}
        pub fun getUtilizationRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64
    }

    // IdentityCertificate resource which is used to identify account address or perform caller authentication
    pub resource interface IdentityCertificate {}

    pub resource interface PoolPublic {
        pub fun getPoolAddress(): Address
        pub fun getPoolTypeString(): String
        pub fun getUnderlyingTypeString(): String
        pub fun getUnderlyingToLpTokenRate(): UFix64
        pub fun getAccountLpTokenBalance(account: Address): UFix64
        pub fun getAccountBorrowBalance(account: Address): UFix64
        // Return: [exchangeRate, lpTokenBalance, borrowBalance]
        pub fun getAccountSnapshot(account: Address): [UFix64; 3]
        pub fun getPoolTotalBorrows(): UFix64
        // Accrue pool interest and checkpoint latest data to pool states
        pub fun accrueInterest(): UInt8
        pub fun getPoolCertificateType(): Type
        // Note: Check to ensure @callerPoolCertificate's run-time type is another LendingPool's.IdentityCertificate,
        // so that this public seize function can only be invoked by another LendingPool contract
        pub fun seize(
            seizerPoolCertificate: @{Interfaces.IdentityCertificate},
            seizerPool: Address,
            liquidator: Address,
            borrower: Address,
            borrowerCollateralLpTokenToSeize: UFix64
        )
    }

    pub resource interface OraclePublic {
        // Get the given pool's underlying asset price denominated in USD.
        // Note: Return value of 0.0 means the given pool's price feed is not available.
        pub fun getUnderlyingPrice(pool: Address): UFix64

        // Return latest reported data in [timestamp, priceData]
        pub fun latestResult(pool: Address): [UFix64; 2]

        // Return supported markets' addresses
        pub fun getSupportedFeeds(): [Address]
    }

    pub resource interface ComptrollerPublic {
        pub fun supplyAllowed(
            poolAddress: Address,
            supplierAddress: Address,
            supplyUnderlyingAmount: UFix64
        ): UInt8

        pub fun redeemAllowed(
            poolAddress: Address,
            redeemerAddress: Address,
            redeemLpTokenAmount: UFix64
        ): UInt8

        pub fun borrowAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            borrowUnderlyingAmount: UFix64
        ): UInt8
        
        pub fun repayAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            repayUnderlyingAmount: UFix64
        ): UInt8

        pub fun liquidateAllowed(
            poolBorrowed: Address,
            poolCollateralized: Address,
            borrower: Address,
            repayUnderlyingAmount: UFix64
        ): UInt8

        pub fun seizeAllowed(
            borrowPool: Address,
            collateralPool: Address,
            liquidator: Address,
            borrower: Address,
            seizeCollateralPoolLpTokenAmount: UFix64
        ): UInt8

        pub fun calculateCollateralPoolLpTokenToSeize(
            borrower: Address,
            borrowPool: Address,
            collateralPool: Address,
            actualRepaidBorrowAmount: UFix64
        ): UFix64

        pub fun getUserCertificateType(): Type

        pub fun callerAllowed(
            callerCertificate: @{Interfaces.IdentityCertificate},
            callerAddress: Address
        ): UInt8
    }
}