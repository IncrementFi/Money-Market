pub contract interface IntereatRateModel {
    pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64
    pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64
}