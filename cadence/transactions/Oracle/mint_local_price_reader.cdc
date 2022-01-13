import OracleInterface from "../../contracts/OracleInterface.cdc"
import OracleConfig from "../../contracts/OracleConfig.cdc"

transaction(oracleAddr: Address) {
    prepare(readerAccount: AuthAccount) {
        log("Transaction Start --------------- mint local price reader")
        
        let oraclePublicInterface_ReaderRef = getAccount(oracleAddr).getCapability<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath).borrow()
                                              ?? panic("Lost oracle public capability at ".concat(oracleAddr.toString()))
        let priceReaderSuggestedPath = oraclePublicInterface_ReaderRef.getPriceReaderStoragePath()
        // check if alraedy minted
        if (readerAccount.borrow<&OracleInterface.PriceReader>(from: priceReaderSuggestedPath) == nil) {
            let oraclePublicInterface_ReaderRef = getAccount(oracleAddr).getCapability<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath).borrow()
                                ?? panic("Lost oracle public capability at ".concat(oracleAddr.toString()))

            let priceReader <- oraclePublicInterface_ReaderRef.mintPriceReader()

            readerAccount.save(<- priceReader, to: priceReaderSuggestedPath)
        }

        log("End -----------------------------")
    }
}