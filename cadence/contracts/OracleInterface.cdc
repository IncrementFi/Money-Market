/**
  * @Desc This contract is the interface description of TokenPriceOracle.
  *  The oracle includes an medianizer, which obtains prices from multiple feeds and calculate the median as the final price.
  * 
  * @Author Increment Labs
  *
  *  TokenPriceOracle only makes price oracle for a single token.
  *  The contract will accept price offers from multiple feeds.
  *  Feeders are anonymous for now, and its purpose is to protect the providers from extortion.
  *  We welcome more price-feeding institutions and partners to join in and build a more decentralized oracle on flow.
  *
  *  Currently, the use of this oracle is limited to addresses in the whitelist, and applications can be submitted to Increment Labs.
  *
  * @Concepts
  *  Feed1(off-chain) --> PricePanel(resource) ---- 3.4 ---->
  *  Feed2(off-chain) --> PricePanel(resource) ---- 3.2 ----> PriceOracle(contract) ->  Medianizer -> 3.4 -----> Readers
  *  Feed3(off-chain) --> PricePanel(resource) ---- 3.6 ---->
*/

pub contract interface OracleInterface {

    // @Desc Reader related public interfaces opened on TokenPriceOracle smart contract
    pub resource interface OracleReaderPublic {

        // @Desc Get the median price of all current feeds.
        // @Param ReaderCertificate - The caller needs to provide a reader certificate
        // @Return Median price, returns 0.0 if the current price is invalid
        pub fun getMedianPrice(readerCertificate: &ReaderCertificate): UFix64

        // @Desc Apply for a certificate of reader
        // @Return Resource of certificate - This resource must be stored in local storage
        //  and kept for yourself. Please do not expose the capability to others.
        pub fun applyReaderCertificate(): @ReaderCertificate
    }

    // @Desc Feader related public interfaces opened on TokenPriceOracle smart contract
    pub resource interface OracleFeaderPublic {

        // @Desc Feaders need to mint their own price panels and expose the exact public path to oralce contract
        // @Return Resource of price panel
        pub fun mintFeaderPricePanel(): @FeaderPricePanel

        // @Desc The oracle contract will get the feeding-price based on this path
        // Feeders need to expose their price panel capabilities at this public path
        pub fun getPricePanelPublicPath(): PublicPath
        pub fun getPricePanelStoragePath(): StoragePath
        
    }

    // @Desc Panel for publishing price. Every feeder needs to mint this resource locally.
    pub resource FeaderPricePanel: FeaderPricePanelPublic {

        // @Desc The feeder uses this function to offer price at the price panel
        // @Param price - price from off-chain
        pub fun publishPrice(price: UFix64)
    }

    pub resource interface FeaderPricePanelPublic {
        // @Desc Get the current feed price, this function can only be called by the TokenPriceOracle contract
        pub fun fetchPrice(certificate: &OracleCertificate): UFix64
    }

    // @Desc IdentityCertificate resource which is used to identify account address or perform caller authentication
    pub resource interface IdentityCertificate {}

    // @Desc Each oracle contract will hold its own certificate to identify itself.
    // Only the oracle contract can mint the certificate.
    pub resource OracleCertificate: IdentityCertificate {}

    // @Desc Reader certificate is used to provide proof of its address. In fact, anyone can mint their reader certificate.
    // Readers only need to apply for a certificate to any oracle contract once.
    // The contract will control the read permission of the readers according to the address whitelist.
    // Please do not share your certificate capability with others and take the responsibility of community governance.
    pub resource ReaderCertificate: IdentityCertificate {}



    // @Desc Community administrator, Increment Labs will then collect community feedback and initiate voting for governance.
    pub resource interface Admin {
        pub fun configOracle(tokenTypeIdentifier: String, minFeaderNumber: Int, feaderStoragePath: StoragePath, feaderPublicPath: PublicPath)
        pub fun addFeaderWhiteList(feaderAddr: Address)
        pub fun addReaderWhiteList(readerAddr: Address)
        pub fun delFeaderWhiteList(feaderAddr: Address)
        pub fun delReaderWhiteList(readerAddr: Address)
        pub fun getFeaderWhiteList(): [Address]
        pub fun getReaderWhiteList(): [Address]
        pub fun getFeaderWhiteListPrice(): [UFix64]   
    }
    
}