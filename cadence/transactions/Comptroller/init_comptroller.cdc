
import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"
import Config from "../../contracts/Config.cdc"

transaction() {
    prepare(comptrollerAccount: AuthAccount) {
        log("Transaction Start ---------------")
        
        log("create comptroller:")
        let adminRef = comptrollerAccount.borrow<&ComptrollerV1.Admin>(from: ComptrollerV1.AdminStoragePath) ?? panic("Lost comptroller admin.")

        
        log("End -----------------------------")
    }
}