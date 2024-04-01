import SimpleOracle from "../../contracts/SimpleOracle.cdc"

transaction(poolAddress: Address) {
    prepare(adminAccount: auth(BorrowValue) &Account) {
        let adminRef = adminAccount.storage.borrow<&SimpleOracle.Admin>(from: SimpleOracle.OracleAdminStoragePath)
            ?? panic("Cannot borrow reference to Oracle Admin")
        let oracleRef = adminAccount.storage.borrow<&SimpleOracle.Oracle>(from: SimpleOracle.OracleStoragePath)
            ?? panic("Cannot borrow reference to Oracle")

        adminRef.removePriceFeed(oracleRef: oracleRef, pool: poolAddress)
    }
}