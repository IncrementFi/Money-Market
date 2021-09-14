import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

transaction(
    newBlocksPerYear: UInt64,
    newZeroUtilInterestRatePerYear: UFix64, 
    newCriticalUtilInterestRatePerYear: UFix64,
    newFullUtilInterestRatePerYear: UFix64,
    newCriticalUtilPoint: UFix64
) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&TwoSegmentsInterestRateModel.Admin>(from: TwoSegmentsInterestRateModel.AdminStoragePath)
            ?? panic("Could not borrow reference to InterestRateModel Admin")
        let updateCapability = adminAccount
            .getCapability<&TwoSegmentsInterestRateModel.InterestRateModel>(TwoSegmentsInterestRateModel.InterestRateModelPrivatePath)

        adminRef.updateInterestRateModelParams(
            updateCapability: updateCapability,
            newBlocksPerYear: newBlocksPerYear,
            newZeroUtilInterestRatePerYear: newZeroUtilInterestRatePerYear,
            newCriticalUtilInterestRatePerYear: newCriticalUtilInterestRatePerYear,
            newFullUtilInterestRatePerYear: newFullUtilInterestRatePerYear,
            newCriticalUtilPoint: newCriticalUtilPoint
        )
    }
}
 