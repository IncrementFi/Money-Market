import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingOracle from "../../contracts/LendingOracle.cdc"

pub fun main(oracle: Address): [Address] {
    let oracleGetterRef = getAccount(oracle)
        .getCapability<&{LendingInterfaces.OraclePublic}>(LendingOracle.OraclePublicPath)
        .borrow() ?? panic("Could not borrow reference to OracleGetter")

    return oracleGetterRef.getSupportedFeeds()
}