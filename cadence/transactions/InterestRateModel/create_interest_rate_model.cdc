import InterestRateModelInterface from "../../contracts/InterestRateModelInterface.cdc"
import TwoSegmentsInterestRateModel from "../../contracts/TwoSegmentsInterestRateModel.cdc"

// Note: Only run once.
//       Any subsequent runs will discard existing InterestRateModel resource and create & link a new one.
transaction(
    modelName: String,
    blocksPerYear: UInt64,
    baseRatePerYear: UFix64, 
    baseSlope: UFix64,
    jumpSlope: UFix64,
    criticalUtilRate: UFix64
) {
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
            baseRatePerYear: baseRatePerYear,
            baseSlope: baseSlope,
            jumpSlope: jumpSlope,
            criticalUtilRate: criticalUtilRate
        )
        adminAccount.save(<-newModel, to: TwoSegmentsInterestRateModel.InterestRateModelStoragePath)
        // Create a private capability to InterestRateModel resource, which is only used for adminAccount to update parameters
        adminAccount.link<&TwoSegmentsInterestRateModel.InterestRateModel>(
            TwoSegmentsInterestRateModel.InterestRateModelPrivatePath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
        // Create a public capability to InterestRateModel resource that only exposes InterestRateModelInterface
        adminAccount.link<&{InterestRateModelInterface}>(
            TwoSegmentsInterestRateModel.InterestRateModelPublicPath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
        // Create another public capability to InterestRateModel resource that only exposes InterestRateModelParamsGetter
        adminAccount.link<&{TwoSegmentsInterestRateModel.InterestRateModelParamsGetter}>(
            TwoSegmentsInterestRateModel.InterestRateModelParamsPublicPath,
            target: TwoSegmentsInterestRateModel.InterestRateModelStoragePath
        )
    }
}