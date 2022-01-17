import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import SimpleOracle from "../../contracts/SimpleOracle.cdc"

/// Return pool's underlying asset's price data.
/// Return value of 0.0 means the queried pool's underlying asset's data feed is not available.
pub fun main(oracle: Address, pool: Address): UFix64 {
    let oracleGetterRef = getAccount(oracle)
        .getCapability<&SimpleOracle.Oracle{LendingInterfaces.OraclePublic}>(SimpleOracle.OraclePublicPath)
        .borrow() ?? panic("Could not borrow reference to OracleGetter")

    return oracleGetterRef.getUnderlyingPrice(pool: pool)
}