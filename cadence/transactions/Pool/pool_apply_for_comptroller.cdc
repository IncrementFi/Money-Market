
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncPool from "../../contracts/IncPool.cdc"

import IncComptrollerInterface from "../../contracts/IncComptrollerInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"

transaction() {
    prepare(poolAccount: AuthAccount) {
        log("申请加入comptroller")
        let comptrollerAddress: Address = IncConfig.ComptrollerAddr
        let comptrollerPublicCap = getAccount(comptrollerAddress).getCapability    <&{IncComptrollerInterface.ComptrollerPublic}>    (IncConfig.Comptroller_PublicPath)
        let poolPrivateCap       = poolAccount.getCapability                       <&{IncPoolInterface.PoolPrivate}>                 (IncPool.PoolPath_Private)
        comptrollerPublicCap.borrow()!.applyForPoolList(poolCap: poolPrivateCap)
    }
}