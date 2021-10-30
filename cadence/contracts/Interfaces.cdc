import FungibleToken from "./FungibleToken.cdc"

// Interface definitions all-in-one
pub contract interface Interfaces {
    // TODO: Remove file `InterestRateModelInterface.cdc`
    pub resource interface InterestRateModelPublic {
        pub fun getUtilizationRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64
    }

    pub resource interface Certificate {
        pub let certOwner: Address
        pub let certType: Type
    }

    // Authentication mechanism for composability (Contract intereations with priviledge / safety reuqirements) 
    pub resource interface Auth {}

    // TODO: Remove file `PoolInterface.cdc`
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
        pub fun getAuthType(): Type
        // Note: Check to ensure auth's run-time type is ComptrollerV1.Auth,
        // so that this public seize function can only called by Comptroller
        pub fun seize(
            comptrollerAuth: @{Interfaces.Auth},
            borrowPool: Address,
            liquidator: Address,
            borrower: Address,
            borrowerCollateralLpTokenToSeize: UFix64
        )
    }

    // TODO: Remove file `OracleInterface.cdc`
    pub resource interface OraclePublic {
        // Get the given pool's underlying asset price denominated in USD.
        // Note: Return value of 0.0 means the given yToken price feed is not available.
        pub fun getUnderlyingPrice(pool: Address): UFix64

        // Return latest reported data in [timestamp, priceData]
        pub fun latestResult(pool: Address): [UFix64; 2]

        // Return supported markets' addresses
        pub fun getSupportedFeeds(): [Address]
    }

    // TODO: Remove file `ComptrollerInterface.cdc`
    pub resource interface ComptrollerPublic {
        // pub fun joinMarket(markets: [Address])
        // pub fun exitMarket(market: Address)

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
            borrower: Address
            borrowPool: Address,
            collateralPool: Address,
            actualRepaidBorrowAmount: UFix64
        ): UFix64

        pub fun getAuthType(): Type

        // Process an seize request delegated from LendingPool contract.
        // Check to ensure the auth is minted by one of the LendingPools (auth's run-time type is LendingPool.Auth),
        // so that this public function cannot be called by other accounts arbitrarily.
        pub fun seizeExternal(
            poolAuth: @{Interfaces.Auth},
            borrowPool: Address,
            collateralPoolToSeize: Address,
            liquidator: Address,
            borrower: Address,
            borrowerCollateralLpTokenToSeize: UFix64
        )
    }
}