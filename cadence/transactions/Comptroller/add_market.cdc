import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"

transaction(poolAddr: Address, liquidationPenalty: UFix64, collateralFactor: UFix64, borrowCap: UFix64, isOpen: Bool, isMining: Bool) {
    prepare(comptrollerAccount: AuthAccount) {
        log("Transaction Start --------------- add_market")
        
        log("add market ".concat(poolAddr.toString()))
        let comptrollerAdminRef = comptrollerAccount.borrow<&ComptrollerV1.Admin>(from: ComptrollerV1.AdminStoragePath) ?? panic("Lost comptroller admin.")
        comptrollerAdminRef.addMarket(poolAddress: poolAddr, liquidationPenalty: liquidationPenalty, collateralFactor: collateralFactor)
        
        log("config market")
        comptrollerAdminRef.configMarket(pool: poolAddr, isOpen: isOpen, isMining: isMining, liquidationPenalty: nil, collateralFactor: nil, borrowCap: borrowCap)
        
        log("End -----------------------------")
    }
}