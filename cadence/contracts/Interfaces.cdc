import FungibleToken from "./FungibleToken.cdc"

// Interface definitions all-in-one
pub contract interface Interfaces {
    // TODO: Remove file `InterestRateModelInterface.cdc`
    pub resource interface InterestRateModelPublic {
        pub fun getUtilizationRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64
    }

    // TODO: Remove file `PoolInterface.cdc`
    pub resource interface PoolPublic {
        pub fun getPoolAddress(): Address
        pub fun getPoolTypeString(): String
        pub fun getUnderlyingTypeString(): String
        pub fun getContractBasedVaultBalance(vaultId: UInt64): UFix64
        pub fun getUnderlyingToPoolTokenRateCurrent(): UFix64
        pub fun getAccountBorrowsCurrent(account: Address): UFix64
        pub fun getPoolTotalBorrows(): UFix64
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

        pub fun supplyAllowed(poolAddress: Address, supplyUnderlyingAmount: UFix64): UInt8

        pub fun redeemAllowed(
            poolAddress: Address,
            redeemerAddress: Address,
            redeemerCollaterals: [&FungibleToken.Vault],
            redeemPoolTokenAmount: UFix64
        ): UInt8

        pub fun borrowAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            borrowerCollaterals: [&FungibleToken.Vault],
            borrowUnderlyingAmount: UFix64
        ): UInt8
        
        pub fun repayAllowed(poolAddress: Address, repayUnderlyingAmount: UFix64): UInt8
    }
}