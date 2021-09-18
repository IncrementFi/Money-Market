import SimpleOracle from "../../contracts/SimpleOracle.cdc"

transaction(yToken: Address, maxCapacity: Int) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount
            .borrow<&SimpleOracle.Admin>(from: SimpleOracle.AdminStoragePath)
            ?? panic("Could not borrow reference to Oracle Admin")
        let oracleCap = adminAccount
            .getCapability<&SimpleOracle.Oracle>(SimpleOracle.OraclePrivatePath)

        adminRef.addPriceFeed(oracleCap: oracleCap, yToken: yToken, capacity: maxCapacity)
    }
}