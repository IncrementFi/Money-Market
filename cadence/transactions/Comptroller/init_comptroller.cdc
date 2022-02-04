
import LendingComptroller from "../../contracts/LendingComptroller.cdc"

transaction(oracleAddr: Address, closeFactor: UFix64) {

    let comptrollerAdminRef: &LendingComptroller.Admin

    prepare(comptrollerAccount: AuthAccount) {
        self.comptrollerAdminRef = comptrollerAccount.borrow<&LendingComptroller.Admin>(from: LendingComptroller.AdminStoragePath) ?? panic("Lost comptroller admin.")
    }

    execute {
        self.comptrollerAdminRef.configOracle(oracleAddress: oracleAddr)
        self.comptrollerAdminRef.setCloseFactor(closeFactor: closeFactor)
    }
}