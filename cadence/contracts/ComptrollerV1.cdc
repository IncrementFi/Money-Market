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

    // 1_000_000_000_000_000_000, i.e. 1e18
    pub let scaleFactor: UInt256
    // 100_000_000.0, i.e. 1.0e8
    pub let ufixDecimals: UFix64

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
        // Must be in [0.0, 1.0] x scaleFactor
        pub var scaledCollateralFactor: UInt256
        // maximum totalBorrows this market can reach.
        // Any borrow request that makes totalBorrows greater than borrowCap would be rejected
        // Note: value of 0 represents unlimited cap when market.isOpen is set
        pub var scaledBorrowCap: UInt256
        
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
            let scaledNewCollateralFactor = ComptrollerV1.UFix64ToScaledUInt256(newCollateralFactor)
            if (self.scaledCollateralFactor != scaledNewCollateralFactor) {
                self.scaledCollateralFactor = scaledNewCollateralFactor
            }
        }
        pub fun setBorrowCap(newBorrowCap: UFix64) {
            let scaledNewBorrowCap = ComptrollerV1.UFix64ToScaledUInt256(newBorrowCap)
            if (self.scaledBorrowCap != scaledNewBorrowCap) {
                self.scaledBorrowCap = scaledNewBorrowCap
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
            self.scaledCollateralFactor = ComptrollerV1.UFix64ToScaledUInt256(collateralFactor)
            self.scaledBorrowCap = ComptrollerV1.UFix64ToScaledUInt256(borrowCap)
        }
    }

    // Utility function to convert a UFix64 number to its scaled equivalent in UInt256 format
    // e.g. 0.00015678 => 156780000000000
    access(self) fun UFix64ToScaledUInt256(_ ufixParam: UFix64): UInt256 {
        return UInt256(ufixParam * self.ufixDecimals) * self.scaleFactor / UInt256(self.ufixDecimals)
    }
    // Utility function to convert a fixed point number in form of scaled UInt256 back to UFix64 format
    // e.g. 156780000000000 => 0.00015678
    access(self) fun ScaledUInt256ToUFix64(_ scaledParam: UInt256): UFix64 {
        return UFix64(scaledParam * UInt256(self.ufixDecimals) / self.scaleFactor) / self.ufixDecimals
    }

    // This certificate identifies account address and needs to be stored in storage path locally.
    // User should keep it safe and never give this resource's capability to others
    pub resource UserCertificate: Interfaces.IdentityCertificate {}

    pub fun IssueUserCertificate(): @UserCertificate {
        return <- create UserCertificate()
    }

    pub resource Comptroller: Interfaces.ComptrollerPublic {
        access(self) var oracleCap: Capability<&{Interfaces.OraclePublic}>?
        // Multiplier used to calculate the maximum repayAmount when liquidating a borrow. [0.0, 1.0] x scaleFactor
        access(self) var scaledCloseFactor: UInt256
        // Multiplier representing the discount on collateral that a liquidator receives. [0.0, 1.0] x scaleFactor
        access(self) var scaledLiquidationIncentive: UInt256
        // { poolAddress => Market States }
        access(self) let markets: {Address: Market}
        // { accountAddress => markets the account has either provided liquidity to or borrowed from }
        access(self) let accountMarketsIn: {Address: [Address]}

        // Return 0 for Error.NO_ERROR, i.e. supply allowed
        pub fun supplyAllowed(poolAddress: Address, supplierAddress: Address, supplyUnderlyingAmountScaled: UInt256): UInt8 {
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
            redeemLpTokenAmountScaled: UInt256
        ): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }

            // Hypothetical account liquidity check after PoolToken was redeemed
            // liquidity[1] - shortage if any
            let scaledLiquidity: [UInt256;2] = self.getHypotheticalAccountLiquidity(
                account: redeemerAddress,
                poolToModify: poolAddress,
                scaledAmountLPTokenToRedeem: redeemLpTokenAmountScaled,
                scaledAmountUnderlyingToBorrow: 0
            )
            if (scaledLiquidity[1] > 0) {
                return Error.INSUFFICIENT_REDEEM_LIQUIDITY.rawValue
            }
    
            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: poolAddress,
                account: redeemerAddress,
                scaledRedeemOrRepayAmount: redeemLpTokenAmountScaled
            )

            ///// TODO: Keep the flywheel moving
            ///// updateCompSupplyIndex(poolAddress);
            ///// distributeSupplierComp(poolAddress, redeemerAddress);
            return Error.NO_ERROR.rawValue
        }

        pub fun borrowAllowed(
            poolAddress: Address,
            borrowerAddress: Address,
            borrowUnderlyingAmountScaled: UInt256
        ): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }
            // 1. totalBorrows limit check if not unlimited borrowCap
            let scaledBorrowCap = self.markets[poolAddress]!.scaledBorrowCap
            if (scaledBorrowCap != 0) {
                let scaledTotalBorrowsNew = self.markets[poolAddress]!.poolPublicCap.borrow()!.getPoolTotalBorrowsScaled() + borrowUnderlyingAmountScaled
                if (scaledTotalBorrowsNew > scaledBorrowCap) {
                    return Error.EXCEED_MARKET_BORROW_CAP.rawValue
                }
            }

            // 2. Hypothetical account liquidity check after underlying was borrowed
            // liquidity[1] - shortage if any
            let scaledLiquidity: [UInt256; 2] = self.getHypotheticalAccountLiquidity(
                account: borrowerAddress,
                poolToModify: poolAddress,
                scaledAmountLPTokenToRedeem: 0,
                scaledAmountUnderlyingToBorrow: borrowUnderlyingAmountScaled
            )
            if (scaledLiquidity[1] > 0) {
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

        pub fun repayAllowed(poolAddress: Address, borrowerAddress: Address, repayUnderlyingAmountScaled: UInt256): UInt8 {
            if (self.markets[poolAddress]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }

            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: poolAddress,
                account: borrowerAddress,
                scaledRedeemOrRepayAmount: repayUnderlyingAmountScaled
            )

            ///// TODO: Keep the flywheel moving
            ///// Exp memory borrowIndex = Exp({mantissa: CToken(cToken).borrowIndex()});
            ///// updateCompBorrowIndex(poolAddress, borrowIndex);
            ///// distributeBorrowerComp(poolAddress, borrowerAddress, borrowIndex);
            return Error.NO_ERROR.rawValue
        }

        pub fun liquidateAllowed(poolBorrowed: Address, poolCollateralized: Address, borrower: Address, repayUnderlyingAmountScaled: UInt256): UInt8 {
            if (self.markets[poolBorrowed]?.isOpen != true || self.markets[poolCollateralized]?.isOpen != true) {
                return Error.MARKET_NOT_OPEN.rawValue
            }
            let liquidity = self.getAccountLiquiditySnapshot(account: borrower)
            if liquidity[0] > 0 {
                return Error.LIQUIDATION_NOT_ALLOWED_FULLY_COLLATERIZED.rawValue
            }
            let scaledBorrowBalance = self.markets[poolBorrowed]!.poolPublicCap.borrow()!.getAccountBorrowBalanceScaled(account: borrower)
            // liquidator cannot repay more than closeFactor * borrow
            if (repayUnderlyingAmountScaled > scaledBorrowBalance * self.scaledCloseFactor / ComptrollerV1.scaleFactor) {
                return Error.LIQUIDATION_NOT_ALLOWED_TOO_MUCH_REPAY.rawValue
            }
            return Error.NO_ERROR.rawValue
        }

        pub fun seizeAllowed(
            borrowPool: Address,
            collateralPool: Address,
            liquidator: Address,
            borrower: Address,
            seizeCollateralPoolLpTokenAmountScaled: UInt256
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
            actualRepaidBorrowAmountScaled: UInt256
        ): UInt256 {
            let borrowPoolUnderlyingPriceUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: borrowPool)
            let collateralPoolUnderlyingPriceUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: collateralPool)
            assert(
                borrowPoolUnderlyingPriceUSD != 0.0 && collateralPoolUnderlyingPriceUSD != 0.0,
                message: "price feed for market not available, abort"
            )
            // 1. Accrue interests first to use latest collateralPool states to do calculation
            self.markets[collateralPool]!.poolPublicCap.borrow()!.accrueInterest()

            // 2. Calculate collateralPool lpTokenSeizedAmount
            let scaledCollateralUnderlyingToLpTokenRate = self.markets[collateralPool]!.poolPublicCap.borrow()!.getUnderlyingToLpTokenRateScaled()
            let scaledBorrowPoolUnderlyingPriceUSD = ComptrollerV1.UFix64ToScaledUInt256(borrowPoolUnderlyingPriceUSD)
            let scaledCollateralPoolUnderlyingPriceUSD = ComptrollerV1.UFix64ToScaledUInt256(collateralPoolUnderlyingPriceUSD)
            let scaleFactor = ComptrollerV1.scaleFactor
            // collatetalPoolLpTokenPriceUSD = collateralPoolUnderlyingPriceUSD x collateralPoolUnderlyingToLpTokenRate
            // seizedCollateralPoolLpTokenAmount = repaidBorrowWithIncentiveInUSD / collatetalPoolLpTokenPriceUSD
            let scaledActualRepaidBorrowWithIncentiveInUSD =
                scaledBorrowPoolUnderlyingPriceUSD * (scaleFactor + self.scaledLiquidationIncentive) / scaleFactor *
                    actualRepaidBorrowAmountScaled / scaleFactor
            let scaledCollateralPoolLpTokenPriceUSD = scaledCollateralPoolUnderlyingPriceUSD * scaledCollateralUnderlyingToLpTokenRate / scaleFactor
            let scaledCollateralLpTokenSeizedAmount = scaledActualRepaidBorrowWithIncentiveInUSD * scaleFactor / scaledCollateralPoolLpTokenPriceUSD

            // 3. borrower collateralPool lpToken balance check
            let scaledLpTokenAmount = self.markets[collateralPool]!.poolPublicCap.borrow()!.getAccountLpTokenBalanceScaled(account: borrower)
            assert(scaledCollateralLpTokenSeizedAmount <= scaledLpTokenAmount, message: "liquidate: borrower's collateralPoolLpToken seized too much")
            return scaledCollateralLpTokenSeizedAmount
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
        pub fun getAccountLiquiditySnapshot(account: Address): [UInt256; 2] {
            return self.getHypotheticalAccountLiquidity(
                account: account,
                poolToModify: 0x0,
                scaledAmountLPTokenToRedeem: 0,
                scaledAmountUnderlyingToBorrow: 0
            )
        }

        // Remove pool out of user markets list if necessary
        access(self) fun removePoolFromAccountMarketsOnCondition(
            poolAddress: Address,
            account: Address,
            scaledRedeemOrRepayAmount: UInt256
        ): Bool {
            // snapshot[1] - lpTokenBalance; snapshot[2] - borrowBalance
            let snapshot = self.markets[poolAddress]!.poolPublicCap.borrow()!.getAccountSnapshotScaled(account: account)
            if (snapshot[1] == 0 && snapshot[2] == scaledRedeemOrRepayAmount || (snapshot[1] == scaledRedeemOrRepayAmount && snapshot[2] == 0)) {
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
            scaledAmountLPTokenToRedeem: UInt256,
            scaledAmountUnderlyingToBorrow: UInt256
        ): [UInt256; 2] {
            pre {
                scaledAmountLPTokenToRedeem == 0 || scaledAmountUnderlyingToBorrow == 0: "at least one of redeemed or borrowed amount must be zero"
            }
            // Total collateral value normalized in usd
            var sumScaledCollateralNormalized: UInt256 = 0
            // Total borrow value with side-effects normalized in usd
            var sumScaledBorrowWithEffectsNormalized: UInt256 = 0
            for poolAddress in self.accountMarketsIn[account]! {
                let scaledCollateralFactor = self.markets[poolAddress]!.scaledCollateralFactor
                let scaledAccountSnapshot = self.markets[poolAddress]!.poolPublicCap.borrow()!.getAccountSnapshotScaled(account: account)
                let scaledUnderlyingToLpTokenRate = scaledAccountSnapshot[0]
                let scaledLpTokenAmount = scaledAccountSnapshot[1]
                let scaledBorrowBalance = scaledAccountSnapshot[2]
                let underlyingPriceInUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: poolAddress)
                let scaledUnderlyingPriceInUSD = ComptrollerV1.UFix64ToScaledUInt256(underlyingPriceInUSD)
                let scaleFactor = ComptrollerV1.scaleFactor
                if (scaledLpTokenAmount > 0) {
                    sumScaledCollateralNormalized = sumScaledCollateralNormalized +
                        scaledCollateralFactor * scaledUnderlyingPriceInUSD / scaleFactor *
                            scaledUnderlyingToLpTokenRate / scaleFactor * scaledLpTokenAmount / scaleFactor
                }
                if (scaledBorrowBalance > 0) {
                    sumScaledBorrowWithEffectsNormalized = sumScaledBorrowWithEffectsNormalized +
                        scaledBorrowBalance * scaledUnderlyingPriceInUSD / scaleFactor
                }
                if (poolAddress == poolToModify) {
                    // Apply hypothetical redeem side-effect
                    if (scaledAmountLPTokenToRedeem > 0) {
                        sumScaledCollateralNormalized = sumScaledCollateralNormalized - 
                            scaledCollateralFactor * scaledUnderlyingPriceInUSD / scaleFactor *
                                scaledUnderlyingToLpTokenRate / scaleFactor * scaledAmountLPTokenToRedeem / scaleFactor
                    }
                    // Apply hypothetical borrow side-effect
                    if (scaledAmountUnderlyingToBorrow > 0) {
                        sumScaledBorrowWithEffectsNormalized = sumScaledBorrowWithEffectsNormalized +
                            scaledAmountUnderlyingToBorrow * scaledUnderlyingPriceInUSD / scaleFactor
                    }
                }
            }
            if (sumScaledCollateralNormalized > sumScaledBorrowWithEffectsNormalized) {
                return [sumScaledCollateralNormalized - sumScaledBorrowWithEffectsNormalized, 0]
            } else {
                return [0, sumScaledBorrowWithEffectsNormalized - sumScaledCollateralNormalized]
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
            let oldCollateralFactor = ComptrollerV1.ScaledUInt256ToUFix64(self.markets[pool]?.scaledCollateralFactor ?? (0 as UInt256))
            if (collateralFactor != nil) {
                self.markets[pool]!.setCollateralFactor(newCollateralFactor: collateralFactor!)
            }
            let oldBorrowCap = ComptrollerV1.ScaledUInt256ToUFix64(self.markets[pool]?.scaledBorrowCap ?? (0 as UInt256))
            if (borrowCap != nil) {
                self.markets[pool]!.setBorrowCap(newBorrowCap: borrowCap!)
            }
            emit ConfigMarketParameters(
                market: pool,
                oldIsOpen: oldOpen, newIsOpen: self.markets[pool]?.isOpen,
                oldIsMining: oldMining, newIsMining: self.markets[pool]?.isMining,
                oldCollateralFactor: oldCollateralFactor, newCollateralFactor: collateralFactor,
                oldBorrowCap: oldBorrowCap, newBorrowCap: borrowCap
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
            let oldCloseFactor = ComptrollerV1.ScaledUInt256ToUFix64(self.scaledCloseFactor)
            self.scaledCloseFactor = ComptrollerV1.UFix64ToScaledUInt256(newCloseFactor)
            emit NewCloseFactor(oldCloseFactor, newCloseFactor)
        }

        access(contract) fun setLiquidationIncentive(newLiquidationIncentive: UFix64) {
            pre {
                newLiquidationIncentive <= 1.0: "value out of range 1.0"
            }
            let oldLiquidationIncentive = ComptrollerV1.ScaledUInt256ToUFix64(self.scaledLiquidationIncentive)
            self.scaledLiquidationIncentive = ComptrollerV1.UFix64ToScaledUInt256(newLiquidationIncentive)
            emit NewLiquidationIncentive(oldLiquidationIncentive, newLiquidationIncentive)
        }

        init() {
            self.oracleCap = nil
            self.scaledCloseFactor = 0
            self.scaledLiquidationIncentive = 0
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

        // 1e18
        self.scaleFactor = 1_000_000_000_000_000_000
        // 1.0e8
        self.ufixDecimals = 100_000_000.0

        self.comptrollerAddress = self.account.address
        self.account.save(<-create Admin(), to: self.AdminStoragePath)
        
        self.account.save(<-create Comptroller(), to: self.ComptrollerStoragePath)
        self.account.link<&{Interfaces.ComptrollerPublic}>(self.ComptrollerPublicPath, target: self.ComptrollerStoragePath)
    }
}