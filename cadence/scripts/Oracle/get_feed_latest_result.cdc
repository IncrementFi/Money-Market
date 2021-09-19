import OracleInterface from "../../contracts/OracleInterface.cdc"
import SimpleOracle from "../../contracts/SimpleOracle.cdc"

// Return yToken's underlying asset's latest data in [timestamp, priceData].
// Return value of [0.0, 0.0] means the queried yToken feed is not available.
pub fun main(oracle: Address, yToken: Address): [UFix64; 2] {
    let oracleGetterRef = getAccount(oracle)
        .getCapability<&SimpleOracle.Oracle{OracleInterface.Getter}>(SimpleOracle.OraclePublicPath)
        .borrow() ?? panic("Could not borrow reference to OracleGetter")

    return oracleGetterRef.latestResult(yToken: yToken)
}