import SimpleOracle from "../../contracts/SimpleOracle.cdc"

// Note: Essentially only need to run once.
transaction() {
    prepare(updater: AuthAccount) {
        destroy <-updater.load<@AnyResource>(from: SimpleOracle.UpdaterStoragePath)
        updater.save(<-SimpleOracle.createUpdateProxy(), to: SimpleOracle.UpdaterStoragePath)
        // Create public capability to OracleUpdateProxy resource that the exposed interface can only be invoked
        // by Oracle resource admin, which is ensured by the type system.
        updater.unlink(SimpleOracle.UpdaterPublicPath)
        updater.link<&SimpleOracle.OracleUpdateProxy{SimpleOracle.OracleUpdateProxyPublic}>(
            SimpleOracle.UpdaterPublicPath,
            target: SimpleOracle.UpdaterStoragePath
        )
    }
}