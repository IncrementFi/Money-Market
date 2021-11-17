import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

// TODO: Do not break arguments into multi-lines unless this bug has been fixed: https://github.com/onflow/flow-cadut/issues/15

transaction(newBlocksPerYear: UInt256, newScaleFactor: UInt256, newScaledZeroUtilInterestRatePerYear: UInt256, newScaledCriticalUtilInterestRatePerYear: UInt256, newScaledFullUtilInterestRatePerYear: UInt256, newScaledCriticalUtilPoint: UInt256) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&TwoSegmentsInterestRateModel.Admin>(from: TwoSegmentsInterestRateModel.InterestRateModelAdminStoragePath)
            ?? panic("Could not borrow reference to InterestRateModel Admin")
        let updateCapability = adminAccount
            .getCapability<&TwoSegmentsInterestRateModel.InterestRateModel>(TwoSegmentsInterestRateModel.InterestRateModelPrivatePath)

        adminRef.updateInterestRateModelParams(
            updateCapability: updateCapability,
            newBlocksPerYear: newBlocksPerYear,
            newScaleFactor: newScaleFactor,
            newScaledZeroUtilInterestRatePerYear: newScaledZeroUtilInterestRatePerYear,
            newScaledCriticalUtilInterestRatePerYear: newScaledCriticalUtilInterestRatePerYear,
            newScaledFullUtilInterestRatePerYear: newScaledFullUtilInterestRatePerYear,
            newScaledCriticalUtilPoint: newScaledCriticalUtilPoint
        )
    }
}