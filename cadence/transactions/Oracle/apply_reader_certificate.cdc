import OracleInterface from "../../contracts/OracleInterface.cdc"
import OracleConfig from "../../contracts/OracleConfig.cdc"

transaction(oracleAddr: Address) {
    prepare(readerAccount: AuthAccount) {
        log("Transaction Start --------------- apply for reader certificate")
        
        if (readerAccount.borrow<&OracleInterface.ReaderCertificate>(from: OracleConfig.ReaderCertificateStoragePath) == nil) {
            let oracleReaderPublicRef = getAccount(oracleAddr).getCapability<&{OracleInterface.OracleReaderPublic}>(OracleConfig.OracleReaderPublicPath).borrow()
                                ?? panic("Lost oracle public capability at ".concat(oracleAddr.toString()))

            let readerCertificate <- oracleReaderPublicRef.applyReaderCertificate()

            readerAccount.save(<- readerCertificate, to: OracleConfig.ReaderCertificateStoragePath)
        }

        log("End -----------------------------")
    }
}