import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

transaction(
    newBlocksPerYear: UInt64,
    newBaseRatePerYear: UFix64, 
    newBaseSlope: UFix64,
    newJumpSlope: UFix64,
    newCriticalUtilRate: UFix64
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
            newBaseRatePerYear: newBaseRatePerYear,
            newBaseSlope: newBaseSlope,
            newJumpSlope: newJumpSlope,
            newCriticalUtilRate: newCriticalUtilRate
        )
    }
}
 