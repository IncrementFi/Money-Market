pub contract Config {
    // TwoSegmentsInterestRateModel.InterestRateModelPublicPath
    pub let InterestRateModelPublicPath: PublicPath
    // SimpleOracle.OraclePublicPath
    pub let OraclePublicPath: PublicPath
    // SimpleOracle.UpdaterPublicPath
    pub let UpdaterPublicPath: PublicPath


    pub var ComptrollerAddr: Address
    pub var FUSDPoolAddr: Address
    pub var InterestModelAddr: Address
    pub var OracleAddr: Address

    // LendingPool.PoolPublicStoragePath
    pub var PoolPublicPath: PublicPath

    pub var PoolCertificateStoragePath: StoragePath
    pub var PoolCertificatePrivatePath: PrivatePath
    pub var UserCertificateStoragePath: StoragePath
    pub var UserCertificatePrivatePath: PrivatePath
    init() {
        self.ComptrollerAddr    = 0xf8d6e0586b0a20c7
        self.FUSDPoolAddr       = 0x01cf0e2f2f715450
        self.InterestModelAddr  = 0xf8d6e0586b0a20c7
        self.OracleAddr         = 0xf3fcd2c1a78f5eee

        self.PoolPublicPath     = /public/poolPublic
        self.PoolCertificateStoragePath = /storage/poolCertificate
        self.PoolCertificatePrivatePath = /private/poolCertificate
        self.UserCertificateStoragePath = /storage/incrementalUserCertificate
        self.UserCertificatePrivatePath = /private/incrementalUserCertificate

        self.InterestRateModelPublicPath = /public/InterestRateModel
        self.OraclePublicPath = /public/oracleModule
        self.UpdaterPublicPath = /public/oracleUpdaterProxy
    }
}