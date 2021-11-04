
import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"
import Config from "../../contracts/Config.cdc"

transaction() {
    prepare(comptrollerAccount: AuthAccount) {
        log("Transaction Start --------------- init_comptroller")
        
        log("Init comptroller ")
        let comptrollerAdminRef = comptrollerAccount.borrow<&ComptrollerV1.Admin>(from: ComptrollerV1.AdminStoragePath) ?? panic("Lost comptroller admin.")
        comptrollerAdminRef.configOracle(oracleAddress: Config.OracleAddr)

        log("End -----------------------------")
    }
}