pub contract Config {
    // TwoSegmentsInterestRateModel.InterestRateModelPublicPath
    pub let InterestRateModelPublicPath: PublicPath
    // SimpleOracle.OraclePublicPath
    pub let OraclePublicPath: PublicPath
    // SimpleOracle.UpdaterPublicPath
    pub let UpdaterPublicPath: PublicPath
    // value taken from ComptrollerV1.ComptrollerPublicPath
    pub let ComptrollerPublicPath: PublicPath
    // value taken from ComptrollerV1.UserCertificateStoragePath
    pub var UserCertificateStoragePath: StoragePath
    // value taken from ComptrollerV1.UserCertificatePrivatePath
    pub var UserCertificatePrivatePath: PrivatePath
    // value taken from LendingPool.PoolPublicPublicPath
    pub var PoolPublicPublicPath: PublicPath

    init() {
        self.InterestRateModelPublicPath = /public/InterestRateModel
        self.OraclePublicPath = /public/oracleModule
        self.UpdaterPublicPath = /public/oracleUpdaterProxy
        self.ComptrollerPublicPath = /public/comptrollerModule
        self.UserCertificateStoragePath = /storage/userCertificate
        self.UserCertificatePrivatePath = /private/userCertificate
        self.PoolPublicPublicPath = /public/poolPublic
    }
}