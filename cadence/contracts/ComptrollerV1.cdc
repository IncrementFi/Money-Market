import FungibleToken from "./FungibleToken.cdc"
import Interfaces from "./Interfaces.cdc"

pub contract ComptrollerV1 {
    // The storage path for the Admin resource
    pub let AdminStoragePath: StoragePath
    // The storage path for the Comptroller resource
    pub let ComptrollerStoragePath: StoragePath
    // The private path for the capability to Comptroller resource for admin functions
    pub let ComptrollerPrivatePath: PrivatePath
    // The public path for the capability to restricted to &{Interfaces.ComptrollerPublic}
    pub let ComptrollerPublicPath: PublicPath

    pub event MarketAdded(market: Address, marketType: String, collateralFactor: UFix64)
    pub event NewOracle(_ oldOracleAddress: Address?, _ newOracleAddress: Address)
    pub event ConfigMarketParameters(
        market: Address,
        oldIsOpen: Bool?, newIsOpen: Bool?,
        oldIsMining: Bool?, newIsMining: Bool?,
        oldCollateralFactor: UFix64?, newCollateralFactor: UFix64?,
        oldBorrowCap: UFix64?, newBorrowCap: UFix64?
    )

    pub enum Error: UInt8 {
        pub case NO_ERROR
        pub case MARKET_NOT_OPEN
        pub case INSUFFICIENT_LIQUIDITY
        pub case EXCEED_MARKET_BORROW_CAP
        pub case COLLATERAL_OWNER_AND_ACCOUNT_NOT_MATCH
        pub case COLLATERAL_TYPE_UNRECOGNIZED
    }

    pub struct Market {
        // Pool's type in String format
        pub let poolType: String
        // Contains functions to query public market data
        pub let poolPublic: &{Interfaces.PoolPublic}
        pub var isOpen: Bool
        // Whether or not liquidity mining is enabled for this market
        pub var isMining: Bool
        // The most one can borrow against his collateral in this market
        // Must be in [0.0, 1.0]
        pub var collateralFactor: UFix64
        // maximum totalBorrows this market can reach.
        // Any borrow request that makes totalBorrows greater than borrowCap would be rejected
        // Note: value of 0.0 represents unlimited cap when market.isOpen is set
        pub var borrowCap: UFix64
        // Record of user accounts that have unpaid borrowBalance in this market
        pub let borrowerMembership: {Address: Bool}
        
        pub fun setMarketStatus(isOpen: Bool) {
            if (self.isOpen != isOpen) {
                self.isOpen = isOpen
            }
        }
        pub fun setMiningStatus(isMining: Bool) {
            if (self.isMining != isMining) { 
                self.isMining = isMining
            }
        }
        pub fun setCollateralFactor(newCollateralFactor: UFix64) {
            pre {
                newCollateralFactor <= 1.0: "newCollateralFactor out of range 1.0"
            }
            if (self.collateralFactor != newCollateralFactor) {
                self.collateralFactor = newCollateralFactor
            }
        }
        pub fun setBorrowCap(newBorrowCap: UFix64) {
            if (self.borrowCap != newBorrowCap) {
                self.borrowCap = newBorrowCap
            }
        }
        init(
            poolType: String,
            poolPublic: &{Interfaces.PoolPublic},
            isOpen: Bool,
            isMining: Bool,
            collateralFactor: UFix64,
            borrowCap: UFix64
        ) {
            pre {
                collateralFactor <= 1.0: "collateralFactor out of range 1.0"
            }
            self.poolType = poolType
            self.poolPublic = poolPublic
            self.isOpen = isOpen
            self.isMining = isMining
            self.collateralFactor = collateralFactor
            self.borrowCap = borrowCap
            self.borrowerMembership = {}
        }
    }

    pub resource Comptroller: Interfaces.ComptrollerPublic {
        access(self) var oracle: &{Interfaces.OraclePublic}?
        // { poolAddress => Market States }
        access(self) let markets: {Address: Market}
        // { poolTypeString => poolAddress }
        access(self) let typeToMarketAddress: {String: Address}
        // { userAddress => [market address array] the user has ever borrowed }. It's ok if the user has zero unpaid borrowBalance
        access(self) let accountBorrowMarkets: {Address: [Address]}

        // Add markets to be included in account liquidity calculation
        // pub fun joinMarket(markets: [Address]) {}

        // pub fun exitMarket(market: Address) {}

        // Check passed-in collateral vault types and ownerAddress to ensure security
        access(self) fun collateralSafetyCheck(account: Address, collaterals: [&FungibleToken.Vault]): Error {
            for collateral in collaterals {
                // Checked collaterals must be owned by the specified account
                if (collateral.owner!.address != account) {
                    return Error.COLLATERAL_OWNER_AND_ACCOUNT_NOT_MATCH
                }
                let collateralType = collateral.getType().identifier
                if (self.typeToMarketAddress.containsKey(collateralType) == false) {
                    return Error.COLLATERAL_TYPE_UNRECOGNIZED
                }
            }
            return Error.NO_ERROR
        }

        // Return 0 for Error.NO_ERROR, i.e. supply allowed
        pub fun supplyAllowed(poolAddress: Address, supplyUnderlyingAmount: UFix64): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN as! UInt8
            }
            ///// TODO: Keep the flywheel moving
            ///// updateCompSupplyIndex(cToken);
            ///// distributeSupplierComp(cToken, minter);
            return Error.NO_ERROR as! UInt8
        }

        // Return 0 for Error.NO_ERROR, i.e. redeem allowed
        pub fun redeemAllowed(
            poolAddress: Address,
            redeemerAddress: Address,
            redeemerCollaterals: [&FungibleToken.Vault],
            redeemPoolTokenAmount: UFix64
        ): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN as! UInt8
            }
            // 1. Passed-in collaterals safety check
            let err = self.collateralSafetyCheck(account: redeemerAddress, collaterals: redeemerCollaterals)
            if (err != Error.NO_ERROR) {
                return err as! UInt8
            }

            // 2. Hypothetical account liquidity check after PoolToken was redeemed
            // liquidity[1] - shortage if any
            let liquidity: [UFix64;2] = self.getHypotheticalAccountLiquidity(
                account: redeemerAddress,
                accountCollaterals: redeemerCollaterals,
                poolToModify: poolAddress,
                amountLPTokenToRedeem: redeemPoolTokenAmount,
                amountUnderlyingToBorrow: 0.0
            )
            if (liquidity[1] > 0.0) {
                return Error.INSUFFICIENT_LIQUIDITY as! UInt8
            }
    
            ///// 3. TODO: Keep the flywheel moving
            ///// updateCompSupplyIndex(cToken);
            ///// distributeSupplierComp(cToken, redeemer);
            return Error.NO_ERROR as! UInt8
        }

        pub fun borrowAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            borrowerCollaterals: [&FungibleToken.Vault],
            borrowUnderlyingAmount: UFix64
        ): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN as! UInt8
            }
            // 1. totalBorrows limit check if not unlimited borrowCap
            let borrowCap = self.markets[poolAddress]!.borrowCap
            if (borrowCap != 0.0) {
                let totalBorrowsNew = self.markets[poolAddress]!.poolPublic.getPoolTotalBorrows() + borrowUnderlyingAmount
                if (totalBorrowsNew > borrowCap) {
                    return Error.EXCEED_MARKET_BORROW_CAP as! UInt8
                }
            }

            // 2. Passed-in collaterals safety check
            let err = self.collateralSafetyCheck(account: borrowerAddress, collaterals: borrowerCollaterals)
            if (err != Error.NO_ERROR) {
                return err as! UInt8
            }

            // 3. Hypothetical account liquidity check after underlying was borrowed
            // liquidity[1] - shortage if any
            let liquidity: [UFix64;2] = self.getHypotheticalAccountLiquidity(
                account: borrowerAddress,
                accountCollaterals: borrowerCollaterals,
                poolToModify: poolAddress,
                amountLPTokenToRedeem: 0.0,
                amountUnderlyingToBorrow: borrowUnderlyingAmount
            )
            if (liquidity[1] > 0.0) {
                return Error.INSUFFICIENT_LIQUIDITY as! UInt8
            }

            // 4. 
            // Add to market borrower list
            if (self.markets[poolAddress]!.borrowerMembership[borrowerAddress] != true) {
                self.markets[poolAddress]!.borrowerMembership.insert(key: borrowerAddress, true)
            }
            // Add to user borrowed markets list
            if (self.accountBorrowMarkets[borrowerAddress]?.contains(poolAddress) != true) {
                self.accountBorrowMarkets[borrowerAddress]!.append(poolAddress)
            }

            ///// 5. TODO: Keep the flywheel moving
            ///// Exp memory borrowIndex = Exp({mantissa: CToken(cToken).borrowIndex()});
            ///// updateCompBorrowIndex(cToken, borrowIndex);
            ///// distributeBorrowerComp(cToken, borrower, borrowIndex);
            return Error.NO_ERROR as! UInt8
        }

        pub fun repayAllowed(poolAddress: Address, repayUnderlyingAmount: UFix64): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN as! UInt8
            }
            ///// TODO: Keep the flywheel moving
            ///// Exp memory borrowIndex = Exp({mantissa: CToken(cToken).borrowIndex()});
            ///// updateCompBorrowIndex(cToken, borrowIndex);
            ///// distributeBorrowerComp(cToken, borrower, borrowIndex);
            return Error.NO_ERROR as! UInt8
        }

        // Calculate what the account liquidity would be if the given amounts were redeemed / borrowed
        // accountCollaterals - redeemer / borrower must provide reference to their collateral Vaults to do calculation
        // poolToModify - The market to hypothetically redeem/borrow from
        // amountLPTokenToRedeem - The number of LPTokens to hypothetically redeem
        // amountUnderlyingToBorrow - The amount of underlying to hypothetically borrow
        // Return: 0. hypothetical liquidity redundance more than the collateral requirements
        //         1. hypothetical liquidity shortage below collateral requirements
        access(self) fun getHypotheticalAccountLiquidity(
            account: Address,
            accountCollaterals: [&FungibleToken.Vault],
            poolToModify: Address,
            amountLPTokenToRedeem: UFix64,
            amountUnderlyingToBorrow: UFix64
        ): [UFix64; 2] {
            pre {
                amountLPTokenToRedeem == 0.0 || amountUnderlyingToBorrow == 0.0: "at least one of redeemed or borrowed amount must be zero"
            }
            // Total collateral value normalized in usd
            var sumCollateralNormalized = 0.0
            // Total borrow value with side-effects normalized in usd
            var sumBorrowWithEffectsNormalized = 0.0
            for collateral in accountCollaterals {
                let collateralType = collateral.getType().identifier
                let poolAddress = self.typeToMarketAddress[collateralType]!
                let collateralFactor = self.markets[poolAddress]!.collateralFactor
                let lpTokenAmount = self.markets[poolAddress]!.poolPublic.getContractBasedVaultBalance(vaultId: collateral.uuid)
                let underlyingToLpTokenRate = self.markets[poolAddress]!.poolPublic.getUnderlyingToPoolTokenRateCurrent()
                let underlyingPriceInUSD = self.oracle!.getUnderlyingPrice(pool: poolAddress)
                sumCollateralNormalized =
                    sumCollateralNormalized + collateralFactor * underlyingPriceInUSD * underlyingToLpTokenRate * lpTokenAmount
            }
            for poolAddress in self.accountBorrowMarkets[account]! {
                let poolPublic = self.markets[poolAddress]!.poolPublic
                let borrowBalance = poolPublic.getAccountBorrowsCurrent(account: account)
                let underlyingPriceInUSD = self.oracle!.getUnderlyingPrice(pool: poolAddress)
                sumBorrowWithEffectsNormalized = sumBorrowWithEffectsNormalized + borrowBalance * underlyingPriceInUSD
                // Apply hypothetical side-effect
                if (poolAddress == poolToModify) {
                    if (amountLPTokenToRedeem > 0.0) {
                        let underlyingToLpTokenRate = poolPublic.getUnderlyingToPoolTokenRateCurrent()
                        let collateralFactor = self.markets[poolAddress]!.collateralFactor
                        sumBorrowWithEffectsNormalized =
                            sumBorrowWithEffectsNormalized + collateralFactor * underlyingPriceInUSD * underlyingToLpTokenRate * amountLPTokenToRedeem
                    }
                    if (amountUnderlyingToBorrow > 0.0) {
                        sumBorrowWithEffectsNormalized = sumBorrowWithEffectsNormalized + amountUnderlyingToBorrow * underlyingPriceInUSD
                    }
                }             
            }
            if (sumCollateralNormalized > sumBorrowWithEffectsNormalized) {
                return [sumCollateralNormalized - sumBorrowWithEffectsNormalized, 0.0]
            } else {
                return [0.0, sumBorrowWithEffectsNormalized - sumCollateralNormalized]
            }
        }

        access(contract) fun addMarket(poolAddress: Address, collateralFactor: UFix64) {
            pre {
                self.markets.containsKey(poolAddress) == false: "pool has already been added"
                self.oracle!.getUnderlyingPrice(pool: poolAddress) != 0.0: "price feed for the market is not available yet, abort listing"
            }
            // Add a new market with collateralFactor of 0.0 and borrowCap of 0.0
            // TODO: fix hardcode path
            let poolPublic = getAccount(poolAddress).getCapability<&{Interfaces.PoolPublic}>(/public/poolPublic).borrow()
                ?? panic("cannot borrow reference to PoolPublic")
            let poolType = poolPublic.getType().identifier
            self.markets[poolAddress] =
                Market(poolType: poolType, poolPublic: poolPublic, isOpen: false, isMining: false, collateralFactor: 0.0, borrowCap: 0.0)
            self.typeToMarketAddress[poolType] = poolAddress
            emit MarketAdded(market: poolAddress, marketType: poolType, collateralFactor: collateralFactor)
        }

        // Tune parameters of an already-listed market
        access(contract) fun configMarket(pool: Address, isOpen: Bool?, isMining: Bool?, collateralFactor: UFix64?, borrowCap: UFix64?) {
            pre {
                self.markets.containsKey(pool): "pool has not been supported yet"
            }
            let oldOpen = self.markets[pool]?.isOpen
            if (isOpen != nil) {
                self.markets[pool]!.setMarketStatus(isOpen: isOpen!)
            }
            let oldMining = self.markets[pool]?.isMining
            if (isMining != nil) {
                self.markets[pool]!.setMiningStatus(isMining: isMining!)
            }
            let oldCollateralFactor = self.markets[pool]?.collateralFactor
            if (collateralFactor != nil) {
                self.markets[pool]!.setCollateralFactor(newCollateralFactor: collateralFactor!)
            }
            let oldBorrowCap = self.markets[pool]?.borrowCap
            if (borrowCap != nil) {
                self.markets[pool]!.setBorrowCap(newBorrowCap: borrowCap!)
            }
            emit ConfigMarketParameters(
                market: pool,
                oldIsOpen: oldOpen, newIsOpen: self.markets[pool]?.isOpen,
                oldIsMining: oldMining, newIsMining: self.markets[pool]?.isMining,
                oldCollateralFactor: oldCollateralFactor, newCollateralFactor: self.markets[pool]?.collateralFactor,
                oldBorrowCap: oldBorrowCap, newBorrowCap: self.markets[pool]?.borrowCap
            )
        }

        access(contract) fun configOracle(oracleAddress: Address) {
            let oldOracleAddress = self.oracle?.owner?.address
            // TODO: fix hardcode path
            self.oracle = getAccount(oracleAddress).getCapability<&{Interfaces.OraclePublic}>(/public/oracleModule)
                .borrow() ?? panic("Could not borrow reference to OraclePublic")
            emit NewOracle(oldOracleAddress, self.oracle!.owner!.address)
        }

        init() {
            self.oracle = nil
            self.markets = {}
            self.typeToMarketAddress = {}
            self.accountBorrowMarkets = {}
        }
    }

    pub resource Admin {
        // Admin funciton to create an Comptroller resource
        pub fun createComptrollerResource(): @Comptroller {
            return <- create Comptroller()
        }
        // Admin function to list a new asset pool to the lending market
        // Note: Do not list a new asset pool before the oracle feed is ready
        pub fun addMarket(comptroller: Capability<&Comptroller>, poolAddress: Address, collateralFactor: UFix64) {
             comptroller.borrow()!.addMarket(poolAddress: poolAddress, collateralFactor: collateralFactor)
        }
        // Admin function to config parameters of a listed-market
        pub fun configMarket(
            comptroller: Capability<&Comptroller>,
            pool: Address, isOpen: Bool?, isMining: Bool?, collateralFactor: UFix64?, borrowCap: UFix64?)
        {
            comptroller.borrow()!.configMarket(
                pool: pool, isOpen: isOpen, isMining: isMining, collateralFactor: collateralFactor, borrowCap: borrowCap)
        }
        // Admin function to set a new oracle
        pub fun configOracle(comptroller: Capability<&Comptroller>, oracleAddress: Address) {
            comptroller.borrow()!.configOracle(oracleAddress: oracleAddress)
        }
    }

    init() {
        self.AdminStoragePath = /storage/comptrollerAdmin
        self.ComptrollerStoragePath = /storage/comptrollerModule
        self.ComptrollerPrivatePath = /private/comptrollerModule
        self.ComptrollerPublicPath = /public/comptrollerModule

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
}