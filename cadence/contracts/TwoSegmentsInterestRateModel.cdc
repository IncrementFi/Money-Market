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
        _ oldBlocksPerYear: UInt256, _ newBlocksPerYear: UInt256,
        _ oldScaleFactor: UInt256, _ newScaleFactor: UInt256,
        _ oldScaledBaseRatePerBlock: UInt256, _ newScaledBaseRatePerBlock: UInt256,
        _ oldScaledBaseMultiplierPerBlock: UInt256, _ newScaledBaseMultiplierPerBlock: UInt256,
        _ oldScaledJumpMultiplierPerBlock: UInt256, _ newScaledJumpMultiplierPerBlock: UInt256,
        _ oldScaledCriticalUtilRate: UInt256, _ newScaledCriticalUtilRate: UInt256
    )

    pub resource InterestRateModel: Interfaces.InterestRateModelPublic {
        access(self) let modelName: String
        // See: https://docs.onflow.org/cadence/measuring-time/#time-on-the-flow-blockchain
        access(self) var blocksPerYear: UInt256
        // Scale factor applied to fixed point number calculation. For example: 1e18 means the actual baseRatePerBlock should be self.baseRatePerBlock / 1e18.
        // Note: The use of scale factor is due to fixed point number in cadence is only precise to 1e-8: https://docs.onflow.org/cadence/language/values-and-types/#fixed-point-numbers
        // It'll be truncated and lose accuracy if not scaled up. e.g.: APR 20% (0.2) => 0.2 / 12614400 blocks => 1.5855e-8 -> truncated as 1e-8.
        access(self) var scaleFactor: UInt256
        // The base borrow interest rate per block when utilization rate is 0 (the y-intercept)
        access(self) var scaledBaseRatePerBlock: UInt256
        // The multiplier of utilization rate that gives the base slope of the borrow interest rate when utilRate% <= criticalUtilRate%
        access(self) var scaledBaseMultiplierPerBlock: UInt256
        // The multiplier of utilization rate that gives the jump slope of the borrow interest rate when utilRate% > criticalUtilRate%
        access(self) var scaledJumpMultiplierPerBlock: UInt256
        // The critical point of utilization rate beyond which the jumpMultiplierPerBlock is applied
        access(self) var scaledCriticalUtilRate: UInt256

        // pool's capital utilization rate (scaled up by self.scaleFactor, e.g. 1e18)
        pub fun getUtilizationRate(cash: UInt256, borrows: UInt256, reserves: UInt256): UInt256 {
            if (borrows == 0) {
                return 0
            }
            return borrows * self.scaleFactor / (cash + borrows - reserves);
        }

        // Get the borrow interest rate per block (scaled up by self.scaleFactor, e.g. 1e18)
        pub fun getBorrowRate(cash: UInt256, borrows: UInt256, reserves: UInt256): UInt256 {
            let scaledUtilRate = self.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
            if (scaledUtilRate <= self.scaledCriticalUtilRate) {
                return (self.scaledBaseMultiplierPerBlock * scaledUtilRate / self.scaleFactor + self.scaledBaseRatePerBlock)
            } else {
                let scaledCriticalUtilBorrowRate = self.scaledBaseMultiplierPerBlock * self.scaledCriticalUtilRate / self.scaleFactor + self.scaledBaseRatePerBlock
                return (scaledUtilRate - self.scaledCriticalUtilRate) * self.scaledJumpMultiplierPerBlock / self.scaleFactor + scaledCriticalUtilBorrowRate
            }
        }

        // Get the supply interest rate per block (scaled up by self.scaleFactor, e.g. 1e18)
        pub fun getSupplyRate(cash: UInt256, borrows: UInt256, reserves: UInt256, reserveFactor: UInt256): UInt256 {
            assert(reserveFactor < self.scaleFactor, message: "reserveFactor should always be less than 1.0 * scaleFactor")

            let scaledUtilRate = self.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
            let scaledBorrowRate = self.getBorrowRate(cash: cash, borrows: borrows, reserves: reserves)
            return (self.scaleFactor - reserveFactor) * scaledBorrowRate / self.scaleFactor * scaledUtilRate / self.scaleFactor
        }

        pub fun getInterestRateModelParams(): {String: AnyStruct} {
            return {
                "modelName": self.modelName,
                "blocksPerYear": self.blocksPerYear,
                "scaleFactor": self.scaleFactor,
                "scaledBaseRatePerBlock": self.scaledBaseRatePerBlock,
                "scaledBaseMultiplierPerBlock": self.scaledBaseMultiplierPerBlock,
                "scaledJumpMultiplierPerBlock": self.scaledJumpMultiplierPerBlock,
                "scaledCriticalUtilRate": self.scaledCriticalUtilRate
            }
        }

        access(contract) fun setInterestRateModelParams(
            _ newBlocksPerYear: UInt256,
            _ newScaleFactor: UInt256,
            _ newScaledZeroUtilInterestRatePerYear: UInt256,
            _ newScaledCriticalUtilInterestRatePerYear: UInt256,
            _ newScaledFullUtilInterestRatePerYear: UInt256,
            _ newScaledCriticalUtilPoint: UInt256
        ) {
            pre {
                newScaledCriticalUtilPoint < newScaleFactor: "newScaledCriticalUtilRate should be within (0.0, 1.0) x newScaleFactor"
                newScaledZeroUtilInterestRatePerYear <= newScaledCriticalUtilInterestRatePerYear &&
                newScaledCriticalUtilInterestRatePerYear <= newScaledFullUtilInterestRatePerYear : "Invalid InterestRateModel Parameters"
            }

            let _blocksPerYear = self.blocksPerYear
            self.blocksPerYear = newBlocksPerYear
            let _scaleFactor = self.scaleFactor
            self.scaleFactor = newScaleFactor
            let _scaledBaseRatePerBlock = self.scaledBaseRatePerBlock
            self.scaledBaseRatePerBlock = newScaledZeroUtilInterestRatePerYear / self.blocksPerYear
            let _scaledBaseMultiplierPerBlock = self.scaledBaseMultiplierPerBlock
            self.scaledBaseMultiplierPerBlock = (newScaledCriticalUtilInterestRatePerYear - newScaledZeroUtilInterestRatePerYear) * newScaleFactor / newScaledCriticalUtilPoint / newBlocksPerYear
            let _scaledJumpMultiplierPerBlock = self.scaledJumpMultiplierPerBlock
            self.scaledJumpMultiplierPerBlock = (newScaledFullUtilInterestRatePerYear - newScaledCriticalUtilInterestRatePerYear) * newScaleFactor / (newScaleFactor - newScaledCriticalUtilPoint) / newBlocksPerYear
            let _scaledCriticalUtilRate = self.scaledCriticalUtilRate
            self.scaledCriticalUtilRate = newScaledCriticalUtilPoint
            emit InterestRateModelUpdated(
                _blocksPerYear, self.blocksPerYear,
                _scaleFactor, self.scaleFactor,
                _scaledBaseRatePerBlock, self.scaledBaseRatePerBlock,
                _scaledBaseMultiplierPerBlock, self.scaledBaseMultiplierPerBlock,
                _scaledJumpMultiplierPerBlock, self.scaledJumpMultiplierPerBlock,
                _scaledCriticalUtilRate, self.scaledCriticalUtilRate
            )
        }

        /**
        * @param {string}  modelName - e.g. "TwoSegmentsInterestRateModel"
        * @param {UInt256} blocksPerYear - 1s avg blocktime for testnet (31536000 blocks / year), 2.5s avg blocktime for mainnet (12614400 blocks / year).
        * @param {UInt256} scaleFactor - Scale factor applied to per-block fixed point number.
        *                  For example: 1e18 means the actual baseRatePerBlock should be self.baseRatePerBlock / 1e18.
        * @param {UInt256} scaledZeroUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 0%, e.g. 0.0 x 1e18 (0%)
        * @param {UInt256} scaledCriticalUtilInterestRatePerYear - Borrow interest rate per year when utilization rate hits the critical point, e.g. 0.05 x 1e18 (5%)
        * @param {UInt256} scaledFullUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 100%, e.g. 0.35 x 1e18 (35%)
        * @param {UInt256} scaledCriticalUtilPoint - The critical utilization point beyond which the interest rate jumps (i.e. two-segments interest model), e.g. 0.8 x 1e18 (80%)
        */
        init(
            modelName: String,
            blocksPerYear: UInt256,
            scaleFactor: UInt256,
            scaledZeroUtilInterestRatePerYear: UInt256,
            scaledCriticalUtilInterestRatePerYear: UInt256,
            scaledFullUtilInterestRatePerYear: UInt256,
            scaledCriticalUtilPoint: UInt256
        ) {
            pre {
                scaledCriticalUtilPoint < scaleFactor: "criticalUtilRate should be within (0.0, 1.0) x scaleFactor"
                scaledZeroUtilInterestRatePerYear <= scaledCriticalUtilInterestRatePerYear &&
                scaledCriticalUtilInterestRatePerYear <= scaledFullUtilInterestRatePerYear : "Invalid InterestRateModel Parameters"
            }

            self.modelName = modelName;
            self.blocksPerYear = blocksPerYear
            self.scaleFactor = scaleFactor
            self.scaledBaseRatePerBlock = scaledZeroUtilInterestRatePerYear / blocksPerYear
            self.scaledBaseMultiplierPerBlock = (scaledCriticalUtilInterestRatePerYear - scaledZeroUtilInterestRatePerYear) * scaleFactor / scaledCriticalUtilPoint / blocksPerYear
            self.scaledJumpMultiplierPerBlock = (scaledFullUtilInterestRatePerYear - scaledCriticalUtilInterestRatePerYear) * scaleFactor / (scaleFactor - scaledCriticalUtilPoint) / blocksPerYear
            self.scaledCriticalUtilRate = scaledCriticalUtilPoint
            emit InterestRateModelUpdated(
                0, self.blocksPerYear,
                0, self.scaleFactor,
                0, self.scaledBaseRatePerBlock,
                0, self.scaledBaseMultiplierPerBlock,
                0, self.scaledJumpMultiplierPerBlock,
                0, self.scaledCriticalUtilRate
            )
        }
    }

    pub resource Admin {
        pub fun createInterestRateModel(
            modelName: String,
            blocksPerYear: UInt256,
            scaleFactor: UInt256,
            scaledZeroUtilInterestRatePerYear: UInt256,
            scaledCriticalUtilInterestRatePerYear: UInt256,
            scaledFullUtilInterestRatePerYear: UInt256,
            scaledCriticalUtilPoint: UInt256): @InterestRateModel
        {
            return <- create InterestRateModel(
                modelName: modelName,
                blocksPerYear: blocksPerYear,
                scaleFactor: scaleFactor,
                scaledZeroUtilInterestRatePerYear: scaledZeroUtilInterestRatePerYear,
                scaledCriticalUtilInterestRatePerYear: scaledCriticalUtilInterestRatePerYear,
                scaledFullUtilInterestRatePerYear: scaledFullUtilInterestRatePerYear,
                scaledCriticalUtilPoint: scaledCriticalUtilPoint
            )
        }

        pub fun updateInterestRateModelParams(
            updateCapability: Capability<&InterestRateModel>,
            newBlocksPerYear: UInt256,
            newScaleFactor: UInt256,
            newScaledZeroUtilInterestRatePerYear: UInt256,
            newScaledCriticalUtilInterestRatePerYear: UInt256,
            newScaledFullUtilInterestRatePerYear: UInt256,
            newScaledCriticalUtilPoint: UInt256
        ) {
            updateCapability.borrow()!.setInterestRateModelParams(
                newBlocksPerYear,
                newScaleFactor,
                newScaledZeroUtilInterestRatePerYear,
                newScaledCriticalUtilInterestRatePerYear,
                newScaledFullUtilInterestRatePerYear,
                newScaledCriticalUtilPoint
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