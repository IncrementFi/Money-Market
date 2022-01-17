import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
// TODO: Do not break arguments into multi-lines unless this bug has been fixed: https://github.com/onflow/flow-cadut/issues/15

/// Print current model parameters
pub fun main(model: Address, cash: UInt256, borrows: UInt256, reserves: UInt256): [UInt256; 3] {
    let interestRateModelRef = getAccount(model)
        .getCapability<&{LendingInterfaces.InterestRateModelPublic}>(LendingConfig.InterestRateModelPublicPath)
        .borrow() ?? panic("Could not borrow reference to InterestRateModelParamsGetter")
    let utilRate =  interestRateModelRef.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
    let borrowRate = interestRateModelRef.getBorrowRate(cash: cash, borrows: borrows, reserves: reserves)
    let supplyRate = interestRateModelRef.getSupplyRate(cash: cash, borrows: borrows, reserves: reserves, reserveFactor: 0)
    return [utilRate, borrowRate, supplyRate]
}