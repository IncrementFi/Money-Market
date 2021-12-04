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

    // Scale factor applied to fixed point number calculation. For example: 1e18 means the actual baseRatePerBlock should
    // be baseRatePerBlock / 1e18. Note: The use of scale factor is due to fixed point number in cadence is only precise to 1e-8:
    // https://docs.onflow.org/cadence/language/values-and-types/#fixed-point-numbers
    // It'll be truncated and lose accuracy if not scaled up. e.g.: APR 20% (0.2) => 0.2 / 12614400 blocks => 1.5855e-8
    //  -> truncated as 1e-8.
    pub let scaleFactor: UInt256
    // 100_000_000.0, i.e. 1.0e8
    pub let ufixScale: UFix64

    pub enum Error: UInt8 {
        pub case NO_ERROR
        // Pool related:
        pub case INVALID_PARAMETERS
        pub case INVALID_USER_CERTIFICATE
        pub case INVALID_POOL_CERTIFICATE
        pub case CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
        pub case CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
        pub case CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
        pub case POOL_INITIALIZED
        pub case EMPTY_FUNGIBLE_TOKEN_VAULT
        pub case MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
        pub case INSUFFICIENT_POOL_LIQUIDITY
        pub case REDEEM_FAILED_NO_ENOUGH_LP_TOKEN
        pub case SAME_LIQUIDATOR_AND_BORROWER
        pub case EXTERNAL_SEIZE_FROM_SELF
        pub case EXCEED_TOTAL_RESERVES
        // Comptroller:
        pub case ADD_MARKET_DUPLICATED
        pub case ADD_MARKET_NO_ORACLE_PRICE
        pub case UNKNOWN_MARKET
        pub case MARKET_NOT_OPEN
        pub case REDEEM_NOT_ALLOWED_POSITION_UNDER_WATER
        pub case BORROW_NOT_ALLOWED_EXCEED_BORROW_CAP
        pub case BORROW_NOT_ALLOWED_POSITION_UNDER_WATER
        pub case LIQUIDATION_NOT_ALLOWED_SEIZE_MORE_THAN_BALANCE
        pub case LIQUIDATION_NOT_ALLOWED_POSITION_ABOVE_WATER
        pub case LIQUIDATION_NOT_ALLOWED_TOO_MUCH_REPAY
    }

    pub fun ErrorEncode(msg: String, err: Error): String {
        return "[IncErrorMsg:".concat(msg).concat("]").concat(
               "[IncErrorCode:").concat(err.rawValue.toString()).concat("]")
    }

    // Utility function to convert a UFix64 number to its scaled equivalent in UInt256 format
    // e.g. 184467440737.09551615 (UFix64.max) => 184467440737095516150000000000
    pub fun UFix64ToScaledUInt256(_ f: UFix64): UInt256 {
        let integral = UInt256(f)
        let fractional = f % 1.0
        let ufixScaledInteger =  integral * UInt256(self.ufixScale) + UInt256(fractional * self.ufixScale)
        return ufixScaledInteger * self.scaleFactor / UInt256(self.ufixScale)
    }
    // Utility function to convert a fixed point number in form of scaled UInt256 back to UFix64 format
    // e.g. 184467440737095516150000000000 => 184467440737.09551615
    pub fun ScaledUInt256ToUFix64(_ scaled: UInt256): UFix64 {
        let integral = scaled / self.scaleFactor
        let ufixScaledFractional = (scaled % self.scaleFactor) * UInt256(self.ufixScale) / self.scaleFactor
        return UFix64(integral) + (UFix64(ufixScaledFractional) / self.ufixScale)
    }

    init() {
        self.InterestRateModelPublicPath = /public/InterestRateModel
        self.OraclePublicPath = /public/oracleModule
        self.UpdaterPublicPath = /public/oracleUpdaterProxy
        self.ComptrollerPublicPath = /public/comptrollerModule
        self.UserCertificateStoragePath = /storage/userCertificate
        self.UserCertificatePrivatePath = /private/userCertificate
        self.PoolPublicPublicPath = /public/poolPublic

        // 1e18
        self.scaleFactor = 1_000_000_000_000_000_000
        // 1.0e8
        self.ufixScale = 100_000_000.0
    }
}