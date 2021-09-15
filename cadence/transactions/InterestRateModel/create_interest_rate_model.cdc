import InterestRateModelInterface from "../../contracts/InterestRateModelInterface.cdc"
import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

// TODO: Do not break arguments into multi-lines unless this bug has been fixed: https://github.com/onflow/flow-cadut/issues/15

// Note: Only run once.
//       Any subsequent runs will discard existing InterestRateModel resource and create & link a new one.
transaction(modelName: String, blocksPerYear: UInt64, zeroUtilInterestRatePerYear: UFix64, criticalUtilInterestRatePerYear: UFix64, fullUtilInterestRatePerYear: UFix64, criticalUtilRate: UFix64) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&TwoSegmentsInterestRateModel.Admin>(from: TwoSegmentsInterestRateModel.AdminStoragePath)
            ?? panic("Could not borrow reference to InterestRateModel Admin")

        // Discard any existing contents
        let oldAny <- adminAccount.load<@AnyResource>(from: TwoSegmentsInterestRateModel.InterestRateModelStoragePath)
        destroy oldAny

        // Create and store a new InterestRateModel
        let newModel <- adminRef.createInterestRateModel(
            modelName: modelName,
            blocksPerYear: blocksPerYear,
            zeroUtilInterestRatePerYear: zeroUtilInterestRatePerYear,
            criticalUtilInterestRatePerYear: criticalUtilInterestRatePerYear,
            fullUtilInterestRatePerYear: fullUtilInterestRatePerYear,
            criticalUtilPoint: criticalUtilRate
        )
        adminAccount.save(<-newModel, to: TwoSegmentsInterestRateModel.InterestRateModelStoragePath)
        // Create a private capability to InterestRateModel resource, which is only used for adminAccount to update parameters
        adminAccount.link<&TwoSegmentsInterestRateModel.InterestRateModel>(
            TwoSegmentsInterestRateModel.InterestRateModelPrivatePath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
        // Create a public capability to InterestRateModel resource that only exposes ModelPublic
        adminAccount.link<&TwoSegmentsInterestRateModel.InterestRateModel{InterestRateModelInterface.ModelPublic}>(
            TwoSegmentsInterestRateModel.InterestRateModelPublicPath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
        // Create another public capability to InterestRateModel resource that only exposes ModelParamsGetter
        adminAccount.link<&TwoSegmentsInterestRateModel.InterestRateModel{TwoSegmentsInterestRateModel.ModelParamsGetter}>(
            TwoSegmentsInterestRateModel.InterestRateModelParamsPublicPath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
    }
}