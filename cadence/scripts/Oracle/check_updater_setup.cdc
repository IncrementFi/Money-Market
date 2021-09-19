import SimpleOracle from "../../contracts/SimpleOracle.cdc"

// Checks whether an updater account has been properly setup or not.
pub fun main(updater: Address): Bool {
    let updateCapability = getAccount(updater)
        .getCapability<&SimpleOracle.OracleUpdateProxy{SimpleOracle.OracleUpdateProxyPublic}>(SimpleOracle.UpdaterPublicPath)
        .borrow()
    if (updateCapability != nil && updateCapability!.isUpdaterCapabilityGranted()) {
        return true
    } else {
        return false
    }
}