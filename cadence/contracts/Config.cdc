pub contract Config {

    pub var ComptrollerAddr: Address
    pub var FUSDPoolAddr: Address
    pub var InterestModelAddr: Address

    init() {
        self.ComptrollerAddr    = 0xf8d6e0586b0a20c7
        self.FUSDPoolAddr       = 0x01cf0e2f2f715450
        self.InterestModelAddr  = 0xf8d6e0586b0a20c7
    }
}