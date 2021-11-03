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

    // TODO: remove
    pub var ComptrollerAddr: Address
    pub var FUSDPoolAddr: Address
    pub var InterestModelAddr: Address
    pub var OracleAddr: Address

    init() {
        // TODO: remove
        self.ComptrollerAddr    = 0xf8d6e0586b0a20c7
        self.FUSDPoolAddr       = 0x01cf0e2f2f715450
        self.InterestModelAddr  = 0xf8d6e0586b0a20c7
        self.OracleAddr         = 0xf3fcd2c1a78f5eee

        self.InterestRateModelPublicPath = /public/InterestRateModel
        self.OraclePublicPath = /public/oracleModule
        self.UpdaterPublicPath = /public/oracleUpdaterProxy
        self.ComptrollerPublicPath = /public/comptrollerModule
        self.UserCertificateStoragePath = /storage/userCertificate
        self.UserCertificatePrivatePath = /private/userCertificate
        self.PoolPublicPublicPath = /public/poolPublic
    }
}