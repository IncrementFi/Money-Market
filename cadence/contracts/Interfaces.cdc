import FungibleToken from "./FungibleToken.cdc"

// Interface definitions all-in-one
pub contract interface Interfaces {
    pub resource interface InterestRateModelPublic {
        // exposing model specific fields, e.g.: modelName, model params.
        pub fun getInterestRateModelParams(): {String: AnyStruct}
        // pool's capital utilization rate (scaled up by scaleFactor, e.g. 1e18)
        pub fun getUtilizationRate(cash: UInt256, borrows: UInt256, reserves: UInt256): UInt256
        // Get the borrow interest rate per block (scaled up by scaleFactor, e.g. 1e18)
        pub fun getBorrowRate(cash: UInt256, borrows: UInt256, reserves: UInt256): UInt256
        // Get the supply interest rate per block (scaled up by scaleFactor, e.g. 1e18)
        pub fun getSupplyRate(cash: UInt256, borrows: UInt256, reserves: UInt256, reserveFactor: UInt256): UInt256
        // Get the number of blocks per year.
        pub fun getBlocksPerYear(): UInt256
    }

    // IdentityCertificate resource which is used to identify account address or perform caller authentication
    pub resource interface IdentityCertificate {}

    pub resource interface PoolPublic {
        pub fun getPoolAddress(): Address
        pub fun getPoolTypeString(): String
        pub fun getUnderlyingTypeString(): String
        pub fun getUnderlyingToLpTokenRateScaled(): UInt256
        pub fun getAccountLpTokenBalanceScaled(account: Address): UInt256
        // Return snapshot of account borrowed balance in scaled UInt256 format
        pub fun getAccountBorrowBalanceScaled(account: Address): UInt256
        // Return snapshot of account borrowed balance in UFix64 format
        pub fun getAccountBorrowBalance(account: Address): UFix64
        // Return: [scaledExchangeRate, scaledLpTokenBalance, scaledBorrowBalance]
        pub fun getAccountSnapshotScaled(account: Address): [UInt256; 3]

        pub fun getPoolTotalBorrowsScaled(): UInt256
        pub fun getPoolTotalSupplyScaled(): UInt256
        pub fun getPoolTotalReservesScaled(): UInt256
        pub fun getPoolSupplyApyScaled(): UInt256
        pub fun getPoolBorrowApyScaled(): UInt256
        
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
            scaledBorrowerCollateralLpTokenToSeize: UInt256
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
            supplyUnderlyingAmountScaled: UInt256
        ): UInt8

        pub fun redeemAllowed(
            poolAddress: Address,
            redeemerAddress: Address,
            redeemLpTokenAmountScaled: UInt256
        ): UInt8

        pub fun borrowAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            borrowUnderlyingAmountScaled: UInt256
        ): UInt8
        
        pub fun repayAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            repayUnderlyingAmountScaled: UInt256
        ): UInt8

        pub fun liquidateAllowed(
            poolBorrowed: Address,
            poolCollateralized: Address,
            borrower: Address,
            repayUnderlyingAmountScaled: UInt256
        ): UInt8

        pub fun seizeAllowed(
            borrowPool: Address,
            collateralPool: Address,
            liquidator: Address,
            borrower: Address,
            seizeCollateralPoolLpTokenAmountScaled: UInt256
        ): UInt8

        pub fun calculateCollateralPoolLpTokenToSeize(
            borrower: Address,
            borrowPool: Address,
            collateralPool: Address,
            actualRepaidBorrowAmountScaled: UInt256
        ): UInt256

        pub fun getUserCertificateType(): Type

        pub fun callerAllowed(
            callerCertificate: @{Interfaces.IdentityCertificate},
            callerAddress: Address
        ): UInt8

        pub fun getAllMarketAddrs(): [Address]
        pub fun getMarketInfoByAddr(poolAddr: Address): {String: AnyStruct}
    }
}