import LendingOracle from "../../contracts/LendingOracle.cdc"

transaction(poolAddress: Address, oracleAddr: Address) {
    prepare(adminAccount: AuthAccount) {
        let adminRef = adminAccount.borrow<&LendingOracle.Admin>(from: LendingOracle.OracleAdminStoragePath)
                       ?? panic("Could not borrow reference to Oracle Admin")
        let oracleRef = adminAccount.borrow<&LendingOracle.OracleReaders>(from: LendingOracle.OracleStoragePath)

        adminRef.addPriceFeed(oracleRef: oracleRef!, pool: poolAddress, oracleAddr: oracleAddr)
    }
}