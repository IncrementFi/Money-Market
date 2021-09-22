import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"




transaction() {
    prepare(poolAccount: AuthAccount) {

        log("==================")
        log("获取本地的ctoken minter")
        // GToken与Pool必须部署在同一地址下，不做扩展性考虑，降低复杂度
        let fusdOverlyingAdmin = poolAccount.borrow<&CDToken.Administrator>(from: CDToken.Admin_StoragePath)!
        let overlyingMinter <- fusdOverlyingAdmin.createNewMinter()
        let ledgerManager <- fusdOverlyingAdmin.createLedgerManager()
        
        //
        log("创建本地fusd vault")
        let underlyingVault <- FUSD.createEmptyVault()
        // TODO 暂时不接受外来匿名捐款?

        //
        //
        log("创建pool")
        let pool <- IncPool.test_createPool(
            overlyingMinter: <-overlyingMinter,
            ledgerManager: <-ledgerManager,
            underlyingVault: <-underlyingVault,
            overlyingType: CDToken.Vault.getType(),
            overlyingName: "iFUSD",
            underlyingType: FUSD.Vault.getType(),
            underlyingName: "FUSD"
        )
        poolAccount.save(<-pool, to: IncPool.PoolPath_Storage)
        poolAccount.link    <&{IncPoolInterface.PoolPublic}>          (IncPool.PoolPath_Public,         target: IncPool.PoolPath_Storage)
        poolAccount.link    <&{IncPoolInterface.PoolPrivate}>         (IncPool.PoolPath_Private,        target: IncPool.PoolPath_Storage)
        poolAccount.link    <&{IncPool.PoolSetup}>                    (IncPool.PoolSetUpPath_Public,    target: IncPool.PoolPath_Storage)
        poolAccount.link    <&{IncPoolInterface.PoolTokenInterface}>  (IncPool.PoolTokenPath_Private,   target: IncPool.PoolPath_Storage)
        
        // pool -> token
        let poolTokenInterfaceCap = poolAccount.getCapability                      <&{IncPoolInterface.PoolTokenInterface}> (IncPool.PoolTokenPath_Private)
        fusdOverlyingAdmin.setPoolCap(poolCap: poolTokenInterfaceCap)
        log("------------------")
    }
}
 