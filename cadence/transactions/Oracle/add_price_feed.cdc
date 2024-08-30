import LendingOracle from "../../contracts/LendingOracle.cdc"

transaction(poolAddress: Address, oracleAddr: Address) {
    prepare(adminAccount: auth(BorrowValue) &Account) {
        let adminRef = adminAccount.storage.borrow<&LendingOracle.Admin>(from: LendingOracle.OracleAdminStoragePath)
                       ?? panic("Could not borrow reference to Oracle Admin")
        let oracleRef = adminAccount.storage.borrow<&LendingOracle.OracleReaders>(from: LendingOracle.OracleStoragePath)

        adminRef.addPriceFeed(oracleRef: oracleRef!, pool: poolAddress, oracleAddr: oracleAddr)
    }
}