import LendingComptroller from "../../contracts/LendingComptroller.cdc"

transaction(poolAddr: Address, liquidationPenalty: UFix64, collateralFactor: UFix64, borrowCap: UFix64, isOpen: Bool, isMining: Bool) {
    prepare(comptrollerAccount: AuthAccount) {
        let comptrollerAdminRef = comptrollerAccount.borrow<&LendingComptroller.Admin>(from: LendingComptroller.AdminStoragePath) ?? panic("Lost comptroller admin.")
        
        comptrollerAdminRef.configMarket(pool: poolAddr, isOpen: isOpen, isMining: isMining, liquidationPenalty: liquidationPenalty, collateralFactor: collateralFactor, borrowCap: borrowCap)
    }
}