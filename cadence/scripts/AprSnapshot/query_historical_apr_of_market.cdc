import LendingAprSnapshot from "../../contracts/LendingAprSnapshot.cdc"

// @scale: Spanning of time the drawing should cover - 0 (1 month), 1 (6 months), 2 (1 year). 
// @plotPoints: Maximum data points the drawing needs, e.g. 120 points in maximum
/* @Returns:
        struct Observation {
            timestamp: UFix64
            supplyApr: UFix64
            borrowApr: UFix64
        }
*/
pub fun main(poolAddr: Address, scale: UInt8, plotPoints: UInt64): [LendingAprSnapshot.Observation] {
    return LendingAprSnapshot.queryHistoricalAprData(
        poolAddr: poolAddr,
        scale: scale,
        plotPoints: plotPoints
    )
}