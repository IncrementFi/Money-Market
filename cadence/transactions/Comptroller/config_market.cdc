import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"

transaction(poolAddr: Address, collateralFactor: UFix64, borrowCap: UFix64, isOpen: Bool, isMining: Bool) {
    prepare(comptrollerAccount: AuthAccount) {
        log("Transaction Start --------------- config_market")
        
        log("add market ".concat(poolAddr.toString()))
        let comptrollerAdminRef = comptrollerAccount.borrow<&ComptrollerV1.Admin>(from: ComptrollerV1.AdminStoragePath) ?? panic("Lost comptroller admin.")
        
        log("config market")
        comptrollerAdminRef.configMarket(pool: poolAddr, isOpen: isOpen, isMining: isMining, collateralFactor: collateralFactor, borrowCap: borrowCap)
        
        log("End -----------------------------")
    }
}