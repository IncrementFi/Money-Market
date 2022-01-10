import SimpleOracle from "../../contracts/SimpleOracle.cdc"

transaction(poolAddress: Address) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&SimpleOracle.Admin>(from: SimpleOracle.OracleAdminStoragePath)
            ?? panic("Could not borrow reference to Oracle Admin")
        let oracleCap = adminAccount
            .getCapability<&SimpleOracle.Oracle>(SimpleOracle.OraclePrivatePath)

        adminRef.removePriceFeed(oracleCap: oracleCap, pool: poolAddress)
    }
}