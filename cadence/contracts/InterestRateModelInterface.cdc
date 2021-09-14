pub contract interface InterestRateModelInterface {
    pub resource interface ModelPublic {
        pub fun getUtilizationRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
        pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64
    }
}