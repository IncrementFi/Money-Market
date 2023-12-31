import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import SimpleOracle from "../../contracts/SimpleOracle.cdc"

// Note: Only run once.
//       Any subsequent runs will discard existing Oracle resource and create & link a new one.
transaction() {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&SimpleOracle.Admin>(from: SimpleOracle.OracleAdminStoragePath)
            ?? panic("Could not borrow reference to Oracle Admin")

        // Discard any existing contents
        destroy <-adminAccount.load<@AnyResource>(from: SimpleOracle.OracleStoragePath)
        // Create and store a new Oracle resource
        adminAccount.save(<-adminRef.createOracleResource(), to: SimpleOracle.OracleStoragePath)

        // Create a public capability to Oracle resource that only exposes {OraclePublic} interface to public.
        adminAccount.unlink(SimpleOracle.OraclePublicPath)
        adminAccount.link<&SimpleOracle.Oracle{LendingInterfaces.OraclePublic}>(
            SimpleOracle.OraclePublicPath,
            target: SimpleOracle.OracleStoragePath
        )
        // Create a private capability to Oracle resource for adminAccount to modify data feeds.
        adminAccount.unlink(SimpleOracle.OraclePrivatePath)
        adminAccount.link<&SimpleOracle.Oracle>(
            SimpleOracle.OraclePrivatePath,
            target: SimpleOracle.OracleStoragePath
        )
    }
}