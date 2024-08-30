import SimpleOracle from "../../contracts/SimpleOracle.cdc"

transaction(poolAddress: Address, data: UFix64) {
    prepare(updater: auth(BorrowValue) &Account) {
        let updaterRef = updater.storage.borrow<&SimpleOracle.OracleUpdateProxy>(from: SimpleOracle.UpdaterStoragePath)
            ?? panic("Could not borrow reference to updater proxy")
        
        updaterRef.update(pool: poolAddress, data: data)
    }
}