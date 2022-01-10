/**
  * @Desc This contract stores some commonly used paths for TokenPriceOracle
  * 
  * @Author Increment Labs
*/

pub contract OracleConfig {
    // Admin resource stored in every TokenPriceOracle contract
    pub let OracleAdminPath: StoragePath
    // Reader public interface exposed in every TokenPriceOracle contract
    pub let OracleReaderPublicPath: PublicPath
    // Feader public interface exposed in every TokenPriceOracle contract
    pub let OracleFeaderPublicPath: PublicPath
    // Recommended storage path of reader's certificate
    pub let ReaderCertificateStoragePath: StoragePath

    init() {
        self.OracleAdminPath = /storage/increment_oracle_admin
        self.OracleReaderPublicPath = /public/increment_oracle_reader_public
        self.OracleFeaderPublicPath = /public/increment_oracle_feader_public
        self.ReaderCertificateStoragePath = /storage/increment_oracle_reader_certificate
    }
}