import Interfaces from "./Interfaces.cdc"

pub contract TwoSegmentsInterestRateModel {
    // The storage path for the Admin resource
    pub let InterestRateModelAdminStoragePath: StoragePath
    // The storage path for the InterestRateModel resource
    pub let InterestRateModelStoragePath: StoragePath
    // The private path for the capability to InterestRateModel which is for admin to update model parameters
    pub let InterestRateModelPrivatePath: PrivatePath
    // The public path for the capability restricted to InterestRateModelInterface
    pub let InterestRateModelPublicPath: PublicPath

    // Event which is emitted when Interest Rate Model is created or model parameter gets updated
    pub event InterestRateModelUpdated(
        _ oldBlocksPerYear: UInt64, _ newBlocksPerYear: UInt64,
        _ oldBaseRatePerBlock: UFix64, _ newBaseRatePerBlock: UFix64,
        _ oldBaseMultiplierPerBlock: UFix64, _ newBaseMultiplierPerBlock: UFix64,
        _ oldJumpMultiplierPerBlock: UFix64, _ newJumpMultiplierPerBlock: UFix64,
        _ oldCriticalUtilRate: UFix64, _ newCriticalUtilRate: UFix64
    )

    pub resource InterestRateModel: Interfaces.InterestRateModelPublic {
        access(self) let modelName: String
        // See: https://docs.onflow.org/cadence/measuring-time/#time-on-the-flow-blockchain
        access(self) var blocksPerYear: UInt64
        // The base borrow interest rate per block when utilization rate is 0 (the y-intercept)
        access(self) var baseRatePerBlock: UFix64
        // The multiplier of utilization rate that gives the base slope of the borrow interest rate when utilRate% <= criticalUtilRate%
        access(self) var baseMultiplierPerBlock: UFix64
        // The multiplier of utilization rate that gives the jump slope of the borrow interest rate when utilRate% > criticalUtilRate%
        access(self) var jumpMultiplierPerBlock: UFix64
        // The critical point of utilization rate beyond which the jumpMultiplierPerBlock is applied
        access(self) var criticalUtilRate: UFix64

        pub fun getUtilizationRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64 {
            if (borrows == 0.0) {
                return 0.0
            }
            return borrows / (cash + borrows - reserves);
        }

        // Get the borrow interest rate per block
        pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64 {
            let utilRate = self.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
            if (utilRate <= self.criticalUtilRate) {
                return self.baseMultiplierPerBlock * utilRate + self.baseRatePerBlock
            } else {
                let criticalUtilBorrowRate = self.baseMultiplierPerBlock * self.criticalUtilRate + self.baseRatePerBlock
                return (utilRate - self.criticalUtilRate) * self.jumpMultiplierPerBlock + criticalUtilBorrowRate
            }
        }

        // Get the supply interest rate per block
        pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64 {
            assert(reserveFactor < 1.0, message: "reserveFactor should always be less than 1.0")

            let utilRate = self.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
            let borrowRate = self.getBorrowRate(cash: cash, borrows: borrows, reserves: reserves)
            return (1.0 - reserveFactor) * borrowRate * utilRate
        }

        pub fun getInterestRateModelParams(): {String: AnyStruct} {
            return {
                "modelName": self.modelName,
                "blocksPerYear": self.blocksPerYear,
                "baseRatePerBlock": self.baseRatePerBlock,
                "baseMultiplierPerBlock": self.baseMultiplierPerBlock,
                "jumpMultiplierPerBlock": self.jumpMultiplierPerBlock,
                "criticalUtilRate": self.criticalUtilRate
            }
        }

        access(contract) fun setInterestRateModelParams(
            _ newBlocksPerYear: UInt64,
            _ newZeroUtilInterestRatePerYear: UFix64,
            _ newCriticalUtilInterestRatePerYear: UFix64,
            _ newFullUtilInterestRatePerYear: UFix64,
            _ newCriticalUtilPoint: UFix64
        ) {
            pre {
                newCriticalUtilPoint > 0.0 && newCriticalUtilPoint < 1.0: "criticalUtilRate should be within (0.0, 1.0)"
                newZeroUtilInterestRatePerYear <= newCriticalUtilInterestRatePerYear &&
                newCriticalUtilInterestRatePerYear <= newFullUtilInterestRatePerYear : "Invalid InterestRateModel Parameters"
            }

            let _blocksPerYear = self.blocksPerYear
            self.blocksPerYear = newBlocksPerYear
            let _baseRatePerBlock = self.baseRatePerBlock
            self.baseRatePerBlock = newZeroUtilInterestRatePerYear / UFix64(self.blocksPerYear)            
            let _baseMultiplierPerBlock = self.baseMultiplierPerBlock
            self.baseMultiplierPerBlock = (newCriticalUtilInterestRatePerYear - newZeroUtilInterestRatePerYear) / newCriticalUtilPoint / UFix64(newBlocksPerYear)
            let _jumpMultiplierPerBlock = self.jumpMultiplierPerBlock
            self.jumpMultiplierPerBlock = (newFullUtilInterestRatePerYear - newCriticalUtilInterestRatePerYear) / (1.0 - newCriticalUtilPoint) / UFix64(newBlocksPerYear)
            let _criticalUtilRate = self.criticalUtilRate
            self.criticalUtilRate = newCriticalUtilPoint
            emit InterestRateModelUpdated(
                _blocksPerYear, self.blocksPerYear,
                _baseRatePerBlock, self.baseRatePerBlock,
                _baseMultiplierPerBlock, self.baseMultiplierPerBlock,
                _jumpMultiplierPerBlock, self.jumpMultiplierPerBlock,
                _criticalUtilRate, self.criticalUtilRate
            )
        }

        /**
        * @param {string} modelName - e.g. "TwoSegmentsInterestRateModel"
        * @param {UInt64} blocksPerYear - 1s avg blocktime for testnet (31536000 blocks / year), 2.5s avg blocktime for mainnet (12614400 blocks / year).
        * @param {UFix64} zeroUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 0%, e.g. 0.0 (0%)
        * @param {UFix64} criticalUtilInterestRatePerYear - Borrow interest rate per year when utilization rate hits the critical point, e.g. 0.05 (5%)
        * @param {UFix64} fullUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 100%, e.g. 0.35 (35%)
        * @param {UFix64} criticalUtilPoint - The critical utilization point beyond which the interest rate jumps (i.e. two-segments interest model), e.g. 0.8 (80%)
        */
        init(
            modelName: String,
            blocksPerYear: UInt64,
            zeroUtilInterestRatePerYear: UFix64,
            criticalUtilInterestRatePerYear: UFix64,
            fullUtilInterestRatePerYear: UFix64,
            criticalUtilPoint: UFix64
        ) {
            pre {
                criticalUtilPoint > 0.0 && criticalUtilPoint < 1.0: "criticalUtilRate should be within (0.0, 1.0)"
                zeroUtilInterestRatePerYear <= criticalUtilInterestRatePerYear &&
                criticalUtilInterestRatePerYear <= fullUtilInterestRatePerYear : "Invalid InterestRateModel Parameters"
            }

            self.modelName = modelName;
            self.blocksPerYear = blocksPerYear
            self.baseRatePerBlock = zeroUtilInterestRatePerYear / UFix64(blocksPerYear)
            self.baseMultiplierPerBlock = (criticalUtilInterestRatePerYear - zeroUtilInterestRatePerYear) / criticalUtilPoint / UFix64(blocksPerYear)
            self.jumpMultiplierPerBlock = (fullUtilInterestRatePerYear - criticalUtilInterestRatePerYear) / (1.0 - criticalUtilPoint) / UFix64(blocksPerYear)
            self.criticalUtilRate = criticalUtilPoint
            emit InterestRateModelUpdated(
                0,   self.blocksPerYear,
                0.0, self.baseRatePerBlock,
                0.0, self.baseMultiplierPerBlock,
                0.0, self.jumpMultiplierPerBlock,
                0.0, self.criticalUtilRate
            )
        }
    }

    pub resource Admin {
        pub fun createInterestRateModel(
            modelName: String,
            blocksPerYear: UInt64,
            zeroUtilInterestRatePerYear: UFix64,
            criticalUtilInterestRatePerYear: UFix64,
            fullUtilInterestRatePerYear: UFix64,
            criticalUtilPoint: UFix64): @InterestRateModel
        {
            return <-create InterestRateModel(
                modelName: modelName,
                blocksPerYear: blocksPerYear,
                zeroUtilInterestRatePerYear: zeroUtilInterestRatePerYear,
                criticalUtilInterestRatePerYear: criticalUtilInterestRatePerYear,
                fullUtilInterestRatePerYear: fullUtilInterestRatePerYear,
                criticalUtilPoint: criticalUtilPoint
            )
        }

        pub fun updateInterestRateModelParams(
            updateCapability: Capability<&InterestRateModel>,
            newBlocksPerYear: UInt64,
            newZeroUtilInterestRatePerYear: UFix64,
            newCriticalUtilInterestRatePerYear: UFix64,
            newFullUtilInterestRatePerYear: UFix64,
            newCriticalUtilPoint: UFix64
        ) {
            updateCapability.borrow()!.setInterestRateModelParams(
                newBlocksPerYear,
                newZeroUtilInterestRatePerYear,
                newCriticalUtilInterestRatePerYear,
                newFullUtilInterestRatePerYear,
                newCriticalUtilPoint
            )
        }
    }

    init() {
        self.InterestRateModelAdminStoragePath = /storage/InterestRateModelAdmin
        self.InterestRateModelStoragePath = /storage/InterestRateModel
        self.InterestRateModelPrivatePath = /private/InterestRateModel
        self.InterestRateModelPublicPath = /public/InterestRateModel

        let admin <- create Admin()
        self.account.save(<-admin, to: self.InterestRateModelAdminStoragePath)
    }
}