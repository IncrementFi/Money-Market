pub contract IncConfig {

    pub var ComptrollerAddr: Address
    pub var FUSDPoolAddr: Address

    pub var Comptroller_PublicPath: PublicPath
    pub var Comptroller_PrivatePath: PrivatePath
    init() {
        self.ComptrollerAddr = 0xf8d6e0586b0a20c7
        self.FUSDPoolAddr = 0xf8d6e0586b0a20c7
        self.Comptroller_PublicPath = /public/comptroller
        self.Comptroller_PrivatePath = /private/comptroller
    }

    access(contract) fun setComptrollerAddr(_ addr: Address) { IncConfig.ComptrollerAddr = addr }
    access(contract) fun setFUSDPoolAddr(_ addr: Address) { IncConfig.FUSDPoolAddr = addr }
    access(contract) fun setComptrollerPublicPath(_ path: PublicPath) { IncConfig.Comptroller_PublicPath = path }
    access(contract) fun setComptrollerPrivatePath(_ path: PrivatePath) { IncConfig.Comptroller_PrivatePath = path }
}