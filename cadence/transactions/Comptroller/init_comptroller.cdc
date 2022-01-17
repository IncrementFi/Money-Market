
import LendingComptroller from "../../contracts/LendingComptroller.cdc"

transaction(oracleAddr: Address, closeFactor: UFix64) {
    prepare(comptrollerAccount: AuthAccount) {
        log("Transaction Start --------------- init_comptroller")
        
        log("Init comptroller ")
        let comptrollerAdminRef = comptrollerAccount.borrow<&LendingComptroller.Admin>(from: LendingComptroller.AdminStoragePath) ?? panic("Lost comptroller admin.")
        comptrollerAdminRef.configOracle(oracleAddress: oracleAddr)

        comptrollerAdminRef.setCloseFactor(closeFactor: closeFactor)
        log("End -----------------------------")
    }
}