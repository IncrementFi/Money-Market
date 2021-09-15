import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

// TODO: Do not break arguments into multi-lines unless this bug has been fixed: https://github.com/onflow/flow-cadut/issues/15

// Print current model parameters
pub fun main(model: Address): {String: AnyStruct} {
    let interestRateModelRef = getAccount(model)
        .getCapability<&{TwoSegmentsInterestRateModel.ModelParamsGetter}>(TwoSegmentsInterestRateModel.InterestRateModelParamsPublicPath)
        .borrow() ?? panic("Could not borrow reference to InterestRateModelParamsGetter")
    
    return interestRateModelRef.getInterestRateModelParams()
}