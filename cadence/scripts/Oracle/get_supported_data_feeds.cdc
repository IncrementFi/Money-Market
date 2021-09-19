import OracleInterface from "../../contracts/OracleInterface.cdc"
import SimpleOracle from "../../contracts/SimpleOracle.cdc"

pub fun main(oracle: Address): [Address] {
    let oracleGetterRef = getAccount(oracle)
        .getCapability<&SimpleOracle.Oracle{OracleInterface.Getter}>(SimpleOracle.OraclePublicPath)
        .borrow() ?? panic("Could not borrow reference to OracleGetter")

    return oracleGetterRef.getSupportedFeeds()
}