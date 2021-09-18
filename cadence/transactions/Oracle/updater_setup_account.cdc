import SimpleOracle from "../../contracts/SimpleOracle.cdc"

// Note: Essentially only need to run once.
transaction() {
    prepare(updater: AuthAccount) {
        updater.save(<-SimpleOracle.createUpdateProxy(), to: SimpleOracle.UpdaterStoragePath)
        // Create public capability to OracleUpdateProxy resource that the exposed interface can only be invoked
        // by Oracle resource admin, which is ensured by the type system.
        updater.link<&SimpleOracle.OracleUpdateProxy{SimpleOracle.OracleUpdateProxyPublic}>(
            SimpleOracle.UpdaterPublicPath,
            target: SimpleOracle.UpdaterStoragePath
        )
    }
}