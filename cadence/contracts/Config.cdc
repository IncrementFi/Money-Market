pub contract Config {

    pub var ComptrollerAddr: Address
    pub var FUSDPoolAddr: Address
    pub var InterestModelAddr: Address
    pub var OracleAddr: Address

    pub var PoolPublicPath: PublicPath
    pub var UserCertificateStoragePath: StoragePath
    pub var UserCertificatePrivatePath: PrivatePath
    init() {
        self.ComptrollerAddr    = 0xf8d6e0586b0a20c7
        self.FUSDPoolAddr       = 0x01cf0e2f2f715450
        self.InterestModelAddr  = 0xf8d6e0586b0a20c7
        self.OracleAddr         = 0xf3fcd2c1a78f5eee

        self.PoolPublicPath     = /public/poolPublic
        self.UserCertificateStoragePath = /storage/incrementalUserCertificate
        self.UserCertificatePrivatePath = /private/incrementalUserCertificate

    }
}