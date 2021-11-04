import FungibleToken from "./FungibleToken.cdc"
import Interfaces from "./Interfaces.cdc"
import Config from "./Config.cdc"

pub contract ComptrollerV1 {
    // The storage path for the Admin resource
    pub let AdminStoragePath: StoragePath
    // The storage path for the Comptroller resource
    pub let ComptrollerStoragePath: StoragePath
    // The private path for the capability to Comptroller resource for admin functions
    pub let ComptrollerPrivatePath: PrivatePath
    // The public path for the capability to restricted to &{Interfaces.ComptrollerPublic}
    pub let ComptrollerPublicPath: PublicPath
    // Account address ComptrollerV1 contract is deployed to, i.e. 'the contract address'
    pub let comptrollerAddress: Address
    // Storage path user account stores UserCertificate resource
    pub let UserCertificateStoragePath: StoragePath
    // Path for creating private capability of UserCertificate resource
    pub let UserCertificatePrivatePath: PrivatePath

    pub event MarketAdded(market: Address, marketType: String, collateralFactor: UFix64)
    pub event NewOracle(_ oldOracleAddress: Address?, _ newOracleAddress: Address)
    pub event NewCloseFactor(_ oldCloseFactor: UFix64, _ newCloseFactor: UFix64)
    pub event NewLiquidationIncentive(_ oldLiquidationIncentive: UFix64, _ newLiquidationIncentive: UFix64)
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
        pub case COLLATERAL_LIST_EMPTY
        pub case COLLATERAL_OWNER_AND_ACCOUNT_NOT_MATCH
        pub case COLLATERAL_TYPE_UNRECOGNIZED
        pub case INSUFFICIENT_REDEEM_LIQUIDITY
        pub case INSUFFICIENT_BORROW_LIQUIDITY
        pub case EXCEED_MARKET_BORROW_CAP
        pub case LIQUIDATION_NOT_ALLOWED_FULLY_COLLATERIZED
        pub case LIQUIDATION_NOT_ALLOWED_TOO_MUCH_REPAY
        pub case SET_VALUE_OUT_OF_RANGE
        pub case INVALID_CALLER_CERTIFICATE
    }

    pub struct Market {
        // Contains functions to query public market data
        pub let poolPublicCap: Capability<&{Interfaces.PoolPublic}>
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
            poolPublicCap: Capability<&{Interfaces.PoolPublic}>,
            isOpen: Bool,
            isMining: Bool,
            collateralFactor: UFix64,
            borrowCap: UFix64
        ) {
            pre {
                collateralFactor <= 1.0: "collateralFactor out of range 1.0"
            }
            self.poolPublicCap = poolPublicCap
            self.isOpen = isOpen
            self.isMining = isMining
            self.collateralFactor = collateralFactor
            self.borrowCap = borrowCap
        }
    }

    // This certificate identifies account address and needs to be stored in storage path locally.
    // User should keep it safe and never give this resource's capability to others
    pub resource UserCertificate: Interfaces.IdentityCertificate {}

    pub fun IssueUserCertificate(): @UserCertificate {
        return <- create UserCertificate()
    }

    pub resource Comptroller: Interfaces.ComptrollerPublic {
        access(self) var oracleCap: Capability<&{Interfaces.OraclePublic}>?
        // Multiplier used to calculate the maximum repayAmount when liquidating a borrow. [0.0, 1.0]
        access(self) var closeFactor: UFix64
        // Multiplier representing the discount on collateral that a liquidator receives. [0.0, 1.0]
        access(self) var liquidationIncentive: UFix64
        // { poolAddress => Market States }
        access(self) let markets: {Address: Market}
        // { accountAddress => markets the account has either provided liquidity to or borrowed from }
        access(self) let accountMarketsIn: {Address: [Address]}

        // Return 0 for Error.NO_ERROR, i.e. supply allowed
        pub fun supplyAllowed(poolAddress: Address, supplierAddress: Address, supplyUnderlyingAmount: UFix64): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }

            // Add to user markets list
            if (self.accountMarketsIn.containsKey(supplierAddress) == false) {
                self.accountMarketsIn[supplierAddress] = [poolAddress]
            } else if (self.accountMarketsIn[supplierAddress]!.contains(poolAddress) == false) {
                self.accountMarketsIn[supplierAddress]!.append(poolAddress)
            }

            ///// TODO: Keep the flywheel moving
            ///// updateCompSupplyIndex(poolAddress);
            ///// distributeSupplierComp(poolAddress, supplierAddress);
            return Error.NO_ERROR.rawValue
        }

        // Return 0 for Error.NO_ERROR, i.e. redeem allowed
        pub fun redeemAllowed(
            poolAddress: Address,
            redeemerAddress: Address,
            redeemLpTokenAmount: UFix64
        ): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }

            // Hypothetical account liquidity check after PoolToken was redeemed
            // liquidity[1] - shortage if any
            let liquidity: [UFix64;2] = self.getHypotheticalAccountLiquidity(
                account: redeemerAddress,
                poolToModify: poolAddress,
                amountLPTokenToRedeem: redeemLpTokenAmount,
                amountUnderlyingToBorrow: 0.0
            )
            if (liquidity[1] > 0.0) {
                return Error.INSUFFICIENT_REDEEM_LIQUIDITY.rawValue
            }
    
            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: poolAddress,
                account: redeemerAddress,
                redeemOrRepayAmount: redeemLpTokenAmount
            )

            ///// TODO: Keep the flywheel moving
            ///// updateCompSupplyIndex(poolAddress);
            ///// distributeSupplierComp(poolAddress, redeemerAddress);
            return Error.NO_ERROR.rawValue
        }

        pub fun borrowAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            borrowUnderlyingAmount: UFix64
        ): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }
            // 1. totalBorrows limit check if not unlimited borrowCap
            let borrowCap = self.markets[poolAddress]!.borrowCap
            if (borrowCap != 0.0) {
                let totalBorrowsNew = self.markets[poolAddress]!.poolPublicCap.borrow()!.getPoolTotalBorrows() + borrowUnderlyingAmount
                if (totalBorrowsNew > borrowCap) {
                    return Error.EXCEED_MARKET_BORROW_CAP.rawValue
                }
            }

            // 2. Hypothetical account liquidity check after underlying was borrowed
            // liquidity[1] - shortage if any
            let liquidity: [UFix64;2] = self.getHypotheticalAccountLiquidity(
                account: borrowerAddress,
                poolToModify: poolAddress,
                amountLPTokenToRedeem: 0.0,
                amountUnderlyingToBorrow: borrowUnderlyingAmount
            )
            if (liquidity[1] > 0.0) {
                return Error.INSUFFICIENT_BORROW_LIQUIDITY.rawValue
            }

            // 3. Add to user markets list
            if (self.accountMarketsIn.containsKey(borrowerAddress) == false) {
                self.accountMarketsIn[borrowerAddress] = [poolAddress]
            } else if (self.accountMarketsIn[borrowerAddress]!.contains(poolAddress) == false) {
                self.accountMarketsIn[borrowerAddress]!.append(poolAddress)
            }

            ///// 4. TODO: Keep the flywheel moving
            ///// Exp memory borrowIndex = Exp({mantissa: CToken(cToken).borrowIndex()});
            ///// updateCompBorrowIndex(poolAddress, borrowIndex);
            ///// distributeBorrowerComp(poolAddress, borrowerAddress, borrowIndex);
            return Error.NO_ERROR.rawValue
        }

        pub fun repayAllowed(poolAddress: Address, borrowerAddress: Address, repayUnderlyingAmount: UFix64): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }

            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: poolAddress,
                account: borrowerAddress,
                redeemOrRepayAmount: repayUnderlyingAmount
            )

            ///// TODO: Keep the flywheel moving
            ///// Exp memory borrowIndex = Exp({mantissa: CToken(cToken).borrowIndex()});
            ///// updateCompBorrowIndex(poolAddress, borrowIndex);
            ///// distributeBorrowerComp(poolAddress, borrowerAddress, borrowIndex);
            return Error.NO_ERROR.rawValue
        }

        pub fun liquidateAllowed(poolBorrowed: Address, poolCollateralized: Address, borrower: Address, repayUnderlyingAmount: UFix64): UInt8 {
            if (self.markets[poolBorrowed]?.isOpen != true || self.markets[poolCollateralized]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }
            let liquidity = self.getAccountLiquiditySnapshot(account: borrower)
            if liquidity[0] > 0.0 {
                return Error.LIQUIDATION_NOT_ALLOWED_FULLY_COLLATERIZED.rawValue
            }
            let borrowBalance = self.markets[poolBorrowed]!.poolPublicCap.borrow()!.getAccountBorrowBalance(account: borrower)
            // liquidator cannot repay more than closeFactor * borrow
            if (repayUnderlyingAmount > borrowBalance * self.closeFactor) {
                return Error.LIQUIDATION_NOT_ALLOWED_TOO_MUCH_REPAY.rawValue
            }
            return Error.NO_ERROR.rawValue
        }

        pub fun seizeAllowed(
            borrowPool: Address,
            collateralPool: Address,
            liquidator: Address,
            borrower: Address,
            seizeCollateralPoolLpTokenAmount: UFix64
        ): UInt8 {
            if (self.markets[borrowPool]?.isOpen != true || self.markets[collateralPool]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }

            ///// TODO: Keep the flywheel moving
            ///// updateCompSupplyIndex(collateralPool);
            ///// distributeSupplierComp(collateralPool, borrower);
            ///// distributeSupplierComp(collateralPool, liquidator);
            return Error.NO_ERROR.rawValue
        }

        // Given actualRepaidBorrowAmount underlying of borrowPool, calculate seized number of lpTokens of collateralPool
        // Called in LendingPool.liquidate()
        pub fun calculateCollateralPoolLpTokenToSeize(
            borrower: Address,
            borrowPool: Address,
            collateralPool: Address,
            actualRepaidBorrowAmount: UFix64
        ): UFix64 {
            let borrowPoolUnderlyingPriceUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: borrowPool)
            let collateralPoolUnderlyingPriceUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: collateralPool)
            assert(
                borrowPoolUnderlyingPriceUSD != 0.0 && collateralPoolUnderlyingPriceUSD != 0.0,
                message: "price feed for market not available, abort"
            )
            // 1. Accrue interests first to use latest collateralPool states to do calculation
            self.markets[collateralPool]!.poolPublicCap.borrow()!.accrueInterest()

            // 2. Calculate collateralPool lpTokenSeizedAmount
            let collateralUnderlyingToLpTokenRate = self.markets[collateralPool]!.poolPublicCap.borrow()!.getUnderlyingToLpTokenRate()
            let actualRepaidBorrowWithIncentiveInUSD = (1.0 + self.liquidationIncentive) * borrowPoolUnderlyingPriceUSD * actualRepaidBorrowAmount
            let collateralPoolLpTokenPriceUSD = collateralPoolUnderlyingPriceUSD * collateralUnderlyingToLpTokenRate
            let collateralLpTokenSeizedAmount = actualRepaidBorrowWithIncentiveInUSD / collateralPoolLpTokenPriceUSD
            // 3. borrower collateralPool lpToken balance check
            let lpTokenAmount = self.markets[collateralPool]!.poolPublicCap.borrow()!.getAccountLpTokenBalance(account: borrower)
            assert(collateralLpTokenSeizedAmount <= lpTokenAmount, message: "liquidate: borrower's collateralPoolLpToken seized too much")
            return collateralLpTokenSeizedAmount
        }

        pub fun getUserCertificateType(): Type {
            return Type<@ComptrollerV1.UserCertificate>()
        }

        pub fun callerAllowed(
            callerCertificate: @{Interfaces.IdentityCertificate},
            callerAddress: Address
        ): UInt8 {
            if (self.markets[callerAddress]?.isOpen != true) {
                destroy callerCertificate
                return Error.MARKET_NOT_OPEN.rawValue
            }
            let callerPoolCertificateType = self.markets[callerAddress]!.poolPublicCap.borrow()!.getPoolCertificateType()
            let ret = callerCertificate.isInstance(callerPoolCertificateType)
            destroy callerCertificate
            if (ret == false) {
                return Error.INVALID_CALLER_CERTIFICATE.rawValue
            } else {
                return Error.NO_ERROR.rawValue
            }
        }

        // Return the current account liquidity snapshot:
        // [liquidity redundance more than collateral requirement, liquidity shortage below collateral requirement]
        pub fun getAccountLiquiditySnapshot(account: Address): [UFix64; 2] {
            return self.getHypotheticalAccountLiquidity(
                account: account,
                poolToModify: (0 as! Address),
                amountLPTokenToRedeem: 0.0,
                amountUnderlyingToBorrow: 0.0
            )
        }

        // Remove pool out of user markets list if necessary
        access(self) fun removePoolFromAccountMarketsOnCondition(
            poolAddress: Address,
            account: Address,
            redeemOrRepayAmount: UFix64
        ): Bool {
            // snapshot[1] - lpTokenBalance; snapshot[2] - borrowBalance
            let snapshot = self.markets[poolAddress]!.poolPublicCap.borrow()!.getAccountSnapshot(account: account)
            if (snapshot[1] == 0.0 && snapshot[2] == redeemOrRepayAmount || (snapshot[1] == redeemOrRepayAmount && snapshot[2] == 0.0)) {
                var id = 0
                let marketsIn: &[Address] = &(self.accountMarketsIn[account]!) as &[Address]
                while (id < marketsIn.length) {
                    if (marketsIn[id] == poolAddress) {
                        marketsIn.remove(at: id)
                        return true
                    }
                    id = id + 1
                }
            }
            return false
        }

        // Calculate what the account liquidity would be if the given amounts were redeemed / borrowed
        // poolToModify - The market to hypothetically redeem/borrow from
        // amountLPTokenToRedeem - The number of LPTokens to hypothetically redeem
        // amountUnderlyingToBorrow - The amount of underlying to hypothetically borrow
        // Return: 0. hypothetical liquidity redundance more than the collateral requirements
        //         1. hypothetical liquidity shortage below collateral requirements
        access(self) fun getHypotheticalAccountLiquidity(
            account: Address,
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
            for poolAddress in self.accountMarketsIn[account]! {
                let collateralFactor = self.markets[poolAddress]!.collateralFactor
                let accountSnapshot = self.markets[poolAddress]!.poolPublicCap.borrow()!.getAccountSnapshot(account: account)
                let underlyingToLpTokenRate = accountSnapshot[0]
                let lpTokenAmount = accountSnapshot[1]
                let borrowBalance = accountSnapshot[2]
                let underlyingPriceInUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: poolAddress)
                if (lpTokenAmount > 0.0) {
                    sumCollateralNormalized =
                        sumCollateralNormalized + collateralFactor * underlyingPriceInUSD * underlyingToLpTokenRate * lpTokenAmount
                }
                if (borrowBalance > 0.0) {
                    sumBorrowWithEffectsNormalized = sumBorrowWithEffectsNormalized + borrowBalance * underlyingPriceInUSD
                }
                if (poolAddress == poolToModify) {
                    // Apply hypothetical redeem side-effect
                    if (amountLPTokenToRedeem > 0.0) {
                        sumCollateralNormalized =
                            sumCollateralNormalized - collateralFactor * underlyingPriceInUSD * underlyingToLpTokenRate * amountLPTokenToRedeem
                    }
                    // Apply hypothetical borrow side-effect
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
                self.markets.containsKey(poolAddress) == false:
                    "pool has already been added"
                self.oracleCap!.borrow()!.getUnderlyingPrice(pool: poolAddress) != 0.0:
                    "price feed for the market is not available yet, abort listing"
            }
            // Add a new market with collateralFactor of 0.0 and borrowCap of 0.0
            let poolPublicCap = getAccount(poolAddress).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath)
            assert(poolPublicCap.check() == true, message: "cannot borrow reference to PoolPublic interface")

            self.markets[poolAddress] =
                Market(poolPublicCap: poolPublicCap, isOpen: false, isMining: false, collateralFactor: 0.0, borrowCap: 0.0)
            emit MarketAdded(
                market: poolAddress,
                marketType: poolPublicCap.borrow()!.getUnderlyingTypeString(),
                collateralFactor: collateralFactor
            )
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
            let oldOracleAddress = (self.oracleCap != nil)? self.oracleCap!.borrow()!.owner?.address : nil
            self.oracleCap = getAccount(oracleAddress).getCapability<&{Interfaces.OraclePublic}>(Config.OraclePublicPath)
            emit NewOracle(oldOracleAddress, self.oracleCap!.borrow()!.owner!.address)
        }

        access(contract) fun setCloseFactor(newCloseFactor: UFix64) {
            pre {
                newCloseFactor <= 1.0: "value out of range 1.0"
            }
            let oldCloseFactor = self.closeFactor
            self.closeFactor = newCloseFactor
            emit NewCloseFactor(oldCloseFactor, newCloseFactor)
        }

        access(contract) fun setLiquidationIncentive(newLiquidationIncentive: UFix64) {
            pre {
                newLiquidationIncentive <= 1.0: "value out of range 1.0"
            }
            let oldLiquidationIncentive = self.liquidationIncentive
            self.liquidationIncentive = newLiquidationIncentive
            emit NewLiquidationIncentive(oldLiquidationIncentive, newLiquidationIncentive)
        }

        init() {
            self.oracleCap = nil
            self.closeFactor = 0.0
            self.liquidationIncentive = 0.0
            self.markets = {}
            self.accountMarketsIn = {}
        }
    }

    pub resource Admin {
        // Admin function to list a new asset pool to the lending market
        // Note: Do not list a new asset pool before the oracle feed is ready
        pub fun addMarket(poolAddress: Address, collateralFactor: UFix64) {
            let comptrollerRef = ComptrollerV1.account.borrow<&Comptroller>(from: ComptrollerV1.ComptrollerStoragePath) ?? panic("lost local comptroller.")
            comptrollerRef.addMarket(poolAddress: poolAddress, collateralFactor: collateralFactor)
        }
        // Admin function to config parameters of a listed-market
        pub fun configMarket(pool: Address, isOpen: Bool?, isMining: Bool?, collateralFactor: UFix64?, borrowCap: UFix64?) {
            let comptrollerRef = ComptrollerV1.account.borrow<&Comptroller>(from: ComptrollerV1.ComptrollerStoragePath) ?? panic("lost local comptroller.")
            comptrollerRef.configMarket(
                pool: pool,
                isOpen: isOpen,
                isMining: isMining,
                collateralFactor: collateralFactor,
                borrowCap: borrowCap
            )
        }
        // Admin function to set a new oracle
        pub fun configOracle(oracleAddress: Address) {
            let comptrollerRef = ComptrollerV1.account.borrow<&Comptroller>(from: ComptrollerV1.ComptrollerStoragePath) ?? panic("lost local comptroller.")
            comptrollerRef.configOracle(oracleAddress: oracleAddress)
        }
        // Admin function to set closeFactor
        pub fun setCloseFactor(closeFactor: UFix64) {
            let comptrollerRef = ComptrollerV1.account.borrow<&Comptroller>(from: ComptrollerV1.ComptrollerStoragePath) ?? panic("lost local comptroller.")
            comptrollerRef.setCloseFactor(newCloseFactor: closeFactor)
        }
        // Admin function to set liquidationIncentive
        pub fun setLiquidationIncentive(liquidationIncentive: UFix64) {
            let comptrollerRef = ComptrollerV1.account.borrow<&Comptroller>(from: ComptrollerV1.ComptrollerStoragePath) ?? panic("lost local comptroller.")
            comptrollerRef.setLiquidationIncentive(newLiquidationIncentive: liquidationIncentive)
        }
    }

    init() {
        self.AdminStoragePath = /storage/comptrollerAdmin
        self.ComptrollerStoragePath = /storage/comptrollerModule
        self.ComptrollerPrivatePath = /private/comptrollerModule
        self.ComptrollerPublicPath = /public/comptrollerModule
        self.UserCertificateStoragePath = /storage/userCertificate
        self.UserCertificatePrivatePath = /private/userCertificate

        self.comptrollerAddress = self.account.address
        self.account.save(<-create Admin(), to: self.AdminStoragePath)
        
        self.account.save(<-create Comptroller(), to: self.ComptrollerStoragePath)
        self.account.link<&{Interfaces.ComptrollerPublic}>(self.ComptrollerPublicPath, target: self.ComptrollerStoragePath)
    }
}