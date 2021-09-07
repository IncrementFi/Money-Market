import IntereatRateModel from "./InterestRateModelInterface.cdc"

pub contract TwoSegmentsInterestRateModel: IntereatRateModel {
    pub let moduleName: String
    // The storage path for the admin resource
    pub let AdminStoragePath: StoragePath

    // https://docs.onflow.org/cadence/measuring-time/#time-on-the-flow-blockchain
    access(self) var blocksPerYear: UInt64
    // The base interest rate per block which is the y-intercept when utilization rate is 0
    access(self) var baseRatePerBlock: UFix64
    // The multiplier of utilization rate that gives the slope of the interest rate
    access(self) var baseSlope: UFix64
    // The slope after hitting the critical utilization point
    access(self) var jumpSlope: UFix64
    // The critical point of utilization rate beyond which the jumpSlope is applied
    access(self) var criticalUtilRate: UFix64

    pub event InterestRateModelUpdated(
        _ oldBlocksPerYear: UInt64, _ newBlocksPerYear: UInt64,
        _ oldBaseRatePerBlock: UFix64, _ newBaseRatePerBlock: UFix64,
        _ oldBaseSlope: UFix64, _ newBaseSlope: UFix64,
        _ oldJumpSlope: UFix64, _ newJumpSlope: UFix64,
        _ oldCriticalUtilRate: UFix64, _ newCriticalUtilRate: UFix64
    )

    pub fun getUtilizationRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64 {
        if (borrows == 0.0) {
            return 0.0
        }
        return borrows / (cash + borrows - reserves);
    }

    pub fun getBorrowRate(cash: UFix64, borrows: UFix64, reserves: UFix64): UFix64 {
        let utilRate = self.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
        if (utilRate <= self.criticalUtilRate) {
            return self.baseSlope * utilRate + self.baseRatePerBlock
        } else {
            let criticalUtilBorrowRate = self.baseSlope * self.criticalUtilRate + self.baseRatePerBlock
            return (utilRate - self.criticalUtilRate) * self.jumpSlope + criticalUtilBorrowRate
        }
    }

    pub fun getSupplyRate(cash: UFix64, borrows: UFix64, reserves: UFix64, reserveFactor: UFix64): UFix64 {
        assert(reserveFactor < 1.0, message: "reserveFactor should always be less than 1.0")

        let utilRate = self.getUtilizationRate(cash: cash, borrows: borrows, reserves: reserves)
        let borrowRate = self.getBorrowRate(cash: cash, borrows: borrows, reserves: reserves)
        return (1.0 - reserveFactor) * borrowRate * utilRate
    }

    // Print Interest Rate Model's private parameters
    pub fun getInterestRateModelParams(): {String: AnyStruct} {
        return {
            "blocksPerYear": self.blocksPerYear,
            "baseRatePerBlock": self.baseRatePerBlock,
            "baseSlope": self.baseSlope,
            "jumpSlope": self.jumpSlope,
            "criticalUtilRate": self.criticalUtilRate
        }
    }

    access(contract) fun setInterestRateModelParams(
        _ blocksPerYear: UInt64,
        _ baseRatePerYear: UFix64,
        _ baseSlope: UFix64,
        _ jumpSlope: UFix64,
        _ criticalUtilRate: UFix64
    ) {
        let _blocksPerYear = self.blocksPerYear
        if (blocksPerYear != _blocksPerYear) {
            self.blocksPerYear = blocksPerYear
        }
        let _baseRatePerBlock = self.baseRatePerBlock
        self.baseRatePerBlock = baseRatePerYear / UFix64(self.blocksPerYear)
        let _baseSlope = self.baseSlope
        if (baseSlope != _baseSlope) {
            self.baseSlope = baseSlope
        }
        let _jumpSlope = self.jumpSlope
        if (jumpSlope != _jumpSlope) {
            self.jumpSlope = jumpSlope
        }
        let _criticalUtilRate = self.criticalUtilRate
        if (criticalUtilRate != _criticalUtilRate) {
            self.criticalUtilRate = criticalUtilRate
        }
        emit InterestRateModelUpdated(
            _blocksPerYear, self.blocksPerYear,
            _baseRatePerBlock, self.baseRatePerBlock,
            _baseSlope, self.baseSlope,
            _jumpSlope, self.jumpSlope,
            _criticalUtilRate, self.criticalUtilRate
        )
    }

    pub resource Administrator {
        pub fun updateInterestRateModelParams(
            blocksPerYear: UInt64,
            baseRatePerYear: UFix64,
            baseSlope: UFix64,
            jumpSlope: UFix64,
            criticalUtilRate: UFix64
        ) {
            TwoSegmentsInterestRateModel.setInterestRateModelParams(
                blocksPerYear, baseRatePerYear, baseSlope, jumpSlope, criticalUtilRate
            )
        }
    }

    init(blocksPerYear: UInt64, baseRatePerYear: UFix64, baseSlope: UFix64, jumpSlope: UFix64, criticalUtilRate: UFix64) {
        self.moduleName = "Two Segments Interest Rate Model v1";

        self.blocksPerYear = blocksPerYear
        self.baseRatePerBlock = baseRatePerYear / UFix64(blocksPerYear)
        self.baseSlope = baseSlope
        self.jumpSlope = jumpSlope
        self.criticalUtilRate = criticalUtilRate
        emit InterestRateModelUpdated(
            0,   self.blocksPerYear,
            0.0, self.baseRatePerBlock,
            0.0, self.baseSlope,
            0.0, self.jumpSlope,
            0.0, self.criticalUtilRate
        )

        self.AdminStoragePath = /storage/InterestRateModelAdmin
        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)
    }
}