import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"




transaction() {
    prepare(poolAccount: AuthAccount) {

        log("==================")
        log("获取本地的ctoken minter")
        log("------------------")
    }
}
 