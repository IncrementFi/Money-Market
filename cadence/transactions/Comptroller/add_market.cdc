import LendingComptroller from "../../contracts/LendingComptroller.cdc"

transaction(poolAddr: Address, liquidationPenalty: UFix64, collateralFactor: UFix64, borrowCap: UFix64, isOpen: Bool, isMining: Bool) {
    prepare(comptrollerAccount: AuthAccount) {
        log("Transaction Start --------------- add_market")
        
        log("add market ".concat(poolAddr.toString()))
        let comptrollerAdminRef = comptrollerAccount.borrow<&LendingComptroller.Admin>(from: LendingComptroller.AdminStoragePath) ?? panic("Lost comptroller admin.")
        comptrollerAdminRef.addMarket(poolAddress: poolAddr, liquidationPenalty: liquidationPenalty, collateralFactor: collateralFactor)
        
        log("config market")
        comptrollerAdminRef.configMarket(pool: poolAddr, isOpen: isOpen, isMining: isMining, liquidationPenalty: liquidationPenalty, collateralFactor: collateralFactor, borrowCap: borrowCap)
        
        log("End -----------------------------")
    }
}