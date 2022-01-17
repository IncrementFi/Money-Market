import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"
import Config from "../../contracts/Config.cdc"
// TODO: Do not break arguments into multi-lines unless this bug has been fixed: https://github.com/onflow/flow-cadut/issues/15

// Note: Only run once.
//       Any subsequent runs will discard existing InterestRateModel resource and create & link a new one.
transaction(modelName: String, blocksPerYear: UInt256, scaledZeroUtilInterestRatePerYear: UInt256, scaledCriticalUtilInterestRatePerYear: UInt256, scaledFullUtilInterestRatePerYear: UInt256, scaledCriticalUtilRate: UInt256) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&TwoSegmentsInterestRateModel.Admin>(from: TwoSegmentsInterestRateModel.InterestRateModelAdminStoragePath)
            ?? panic("Could not borrow reference to InterestRateModel Admin")

        // Discard any existing contents
        let oldAny <- adminAccount.load<@AnyResource>(from: TwoSegmentsInterestRateModel.InterestRateModelStoragePath)
        destroy oldAny

        // Create and store a new InterestRateModel
        let newModel <- adminRef.createInterestRateModel(
            modelName: modelName,
            blocksPerYear: blocksPerYear,
            scaledZeroUtilInterestRatePerYear: scaledZeroUtilInterestRatePerYear,
            scaledCriticalUtilInterestRatePerYear: scaledCriticalUtilInterestRatePerYear,
            scaledFullUtilInterestRatePerYear: scaledFullUtilInterestRatePerYear,
            scaledCriticalUtilPoint: scaledCriticalUtilRate
        )
        adminAccount.save(<-newModel, to: TwoSegmentsInterestRateModel.InterestRateModelStoragePath)
        // Create a private capability to InterestRateModel resource, which is only used for adminAccount to update parameters
        adminAccount.unlink(TwoSegmentsInterestRateModel.InterestRateModelPrivatePath)
        adminAccount.link<&TwoSegmentsInterestRateModel.InterestRateModel>(
            TwoSegmentsInterestRateModel.InterestRateModelPrivatePath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
        // Create a public capability to InterestRateModel resource that only exposes ModelPublic
        adminAccount.unlink(Config.InterestRateModelPublicPath)
        adminAccount.link<&TwoSegmentsInterestRateModel.InterestRateModel{LendingInterfaces.InterestRateModelPublic}>(
            Config.InterestRateModelPublicPath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
    }
}