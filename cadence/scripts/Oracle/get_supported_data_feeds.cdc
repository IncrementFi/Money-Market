import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import SimpleOracle from "../../contracts/SimpleOracle.cdc"

pub fun main(oracle: Address): [Address] {
    let oracleGetterRef = getAccount(oracle)
        .getCapability<&SimpleOracle.Oracle{LendingInterfaces.OraclePublic}>(SimpleOracle.OraclePublicPath)
        .borrow() ?? panic("Could not borrow reference to OracleGetter")

    return oracleGetterRef.getSupportedFeeds()
}