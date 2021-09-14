import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

// Print current model parameters
pub fun main(model: Address): {String: AnyStruct} {
    let interestRateModelRef = getAccount(model)
        .getCapability<&{TwoSegmentsInterestRateModel.ModelParamsGetter}>(TwoSegmentsInterestRateModel.InterestRateModelParamsPublicPath)
        .borrow() ?? panic("Could not borrow reference to InterestRateModelParamsGetter")
    
    return interestRateModelRef.getInterestRateModelParams()
}