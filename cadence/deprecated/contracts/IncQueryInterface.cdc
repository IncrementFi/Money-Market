pub contract IncQueryInterface {
    // TODO 这里UFix64够用吗??????
    pub struct UniverseBalance {
        pub(set) var totalSupplyUSD:       UFix64
        pub(set) var totalBorrowUSD:       UFix64
        init(
            totalSupplyUSD:        UFix64,
            totalBorrowUSD:        UFix64
        ) {
            self.totalSupplyUSD        = totalSupplyUSD
            self.totalBorrowUSD        = totalBorrowUSD
        }
    }

    pub struct PoolInfo {
        pub(set) var overlyingName:      String
        pub(set) var underlyingName:     String
        pub(set) var poolAddr:           Address
        pub(set) var isOpen:             Bool
        pub(set) var canDeposit:         Bool
        pub(set) var canRedeem:          Bool
        pub(set) var canBorrow:          Bool
        pub(set) var totalSupply:        UFix64
        pub(set) var totalBorrow:        UFix64
        pub(set) var totalSupplyUSD:     UFix64
        pub(set) var totalBorrowUSD:     UFix64
        pub(set) var apySupply:          UFix64
        pub(set) var apyborrow:          UFix64
        pub(set) var oraclePriceUSD:     UFix64
        init(
            overlyingName:      String,
            underlyingName:     String,
            poolAddr:           Address,
            isOpen:             Bool,
            canDeposit:         Bool,
            canRedeem:          Bool,
            canBorrow:          Bool,
            totalSupply:        UFix64,
            totalBorrow:        UFix64,
            totalSupplyUSD:     UFix64,
            totalBorrowUSD:     UFix64,
            apySupply:          UFix64,
            apyborrow:          UFix64,
            oraclePriceUSD:     UFix64
        ) {
            self.overlyingName      = overlyingName
            self.underlyingName     = underlyingName
            self.poolAddr           = poolAddr
            self.isOpen             = isOpen
            self.canDeposit         = canDeposit
            self.canRedeem          = canRedeem
            self.canBorrow          = canBorrow
            self.totalSupply        = totalSupply
            self.totalBorrow        = totalBorrow
            self.totalSupplyUSD     = totalSupplyUSD
            self.totalBorrowUSD     = totalBorrowUSD
            self.apySupply          = apySupply
            self.apyborrow          = apyborrow
            self.oraclePriceUSD     = oraclePriceUSD
        }
    }

    pub struct UserBalance {
        pub(set) var totalSupplyUSD:       UFix64
        pub(set) var totalBorrowUSD:       UFix64
        pub(set) var apy:                  UFix64
        pub(set) var borrowLimit:          UFix64
        pub(set) var borrowLimitUsed:      UFix64
        init(
            totalSupplyUSD:        UFix64,
            totalBorrowUSD:        UFix64,
            apy:                   UFix64,
            borrowLimit:           UFix64,
            borrowLimitUsed:       UFix64
        ) {
            self.totalSupplyUSD = totalSupplyUSD
            self.totalBorrowUSD = totalBorrowUSD
            self.apy = apy
            self.borrowLimit = borrowLimit
            self.borrowLimitUsed = borrowLimitUsed
        }
    }

    pub struct UserPoolInfo {
        pub(set) var poolAddr:             Address
        pub(set) var totalSupply:          UFix64
        pub(set) var totalSupplyUSD:       UFix64
        pub(set) var totalBorrow:          UFix64
        pub(set) var totalBorrowUSD:       UFix64
        pub(set) var borrowLimit:          UFix64
        pub(set) var borrowLimitUsed:      UFix64
        pub(set) var oraclePriceUSD:       UFix64
        pub(set) var canCollateral:        Bool
        init(
            poolAddr:             Address,
            totalSupply:          UFix64,
            totalSupplyUSD:       UFix64,
            totalBorrow:          UFix64,
            totalBorrowUSD:       UFix64,
            borrowLimit:          UFix64,
            borrowLimitUsed:      UFix64,
            oraclePriceUSD:       UFix64,
            canCollateral:        Bool
        ) {
            self.poolAddr = poolAddr
            self.totalSupply = totalSupply
            self.totalSupplyUSD = totalSupplyUSD
            self.totalBorrow = totalBorrow
            self.totalBorrowUSD = totalBorrowUSD
            self.borrowLimit = borrowLimit
            self.borrowLimitUsed = borrowLimitUsed
            self.oraclePriceUSD = oraclePriceUSD
            self.canCollateral = canCollateral
        }

    }
}