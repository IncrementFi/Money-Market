import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"

import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"

import IncComptroller from "../../contracts/IncComptroller.cdc"


transaction(poolAddress: Address) {
    prepare(comptrollerAccount: AuthAccount) {

        log("==================")
        log("设置新pool的comptroller")
        // TODO 这里都需要做重复检测
        log(poolAddress)
        let poolSetupCap    = getAccount(poolAddress).getCapability<&{IncPool.PoolSetup}>(IncPool.PoolSetUpPath_Public)
        let poolPublicCap   = getAccount(poolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
        // TODO 重新定义private传出的comptroller interface
        let comptrollerCap = comptrollerAccount.getCapability<&IncComptroller.Comptroller>(IncComptroller.Comptroller_PrivatePath)
        // TODO 如果这里把接口类型抽象成interface, 类型的判定就会失效, 需要注册修改模式
        poolSetupCap.borrow()!.setComptroller(comptrollerCap: comptrollerCap)

        // 审批pool请求
        let localComptroller = comptrollerAccount.borrow<&IncComptroller.Comptroller>(from: IncComptroller.Comptroller_StoragePath)!
        localComptroller.approvePoolApplication(poolApproveAddrs: [poolAddress])
        log("------------------")
    }
}
 