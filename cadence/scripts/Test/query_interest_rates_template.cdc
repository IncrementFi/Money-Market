import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

// Print current model parameters
pub fun main(model: Address): [UInt256; 3] {
    let cash: UInt256 = LendingPool.getPoolCash()
    let borrows: UInt256 = LendingPool.scaledTotalBorrows
    let reserves: UInt256 = LendingPool.scaledTotalReserves
    let interestRateModelRef = getAccount(model)
        .getCapability<&{LendingInterfaces.InterestRateModelPublic}>(LendingConfig.InterestRateModelPublicPath)
        .borrow() ?? panic("Could not borrow reference to InterestRateModelParamsGetter")
    let utilRate =  interestRateModelRef.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
    let borrowRate = interestRateModelRef.getBorrowRate(cash: cash, borrows: borrows, reserves: reserves)
    let supplyRate = interestRateModelRef.getSupplyRate(cash: cash, borrows: borrows, reserves: reserves, reserveFactor: 0)
    return [utilRate, borrowRate, supplyRate]
}