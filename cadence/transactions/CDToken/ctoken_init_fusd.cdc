import CDToken from "../../contracts/CDToken.cdc"
import FUSD from "../../contracts/FUSD.cdc"

transaction {

  prepare(signer: AuthAccount) {
    log("==================")
    // 绑定新cToken的underlying类型
    CDToken.bind(
      underlyingName: "FUSD",
      underlyingTokenType: FUSD.getType(),
      MinterProxyFull_StoragePath: /storage/minterproxy_full_fusd,
      MinterProxyReceiver_PublicPath: /public/minterproxy_receiver_fusd,
      VaultPath_Storage: /storage/gtokenVault_fusd_aabb,
      VaultReceiverPath_Pub: /public/gtokenReceiver_fusd_aabb,
      VaultCollateralPath_Priv: /private/gtokenCollateral_fusd_aabb
    )
    log("设置ctoken type -> fusd")
    log("------------------")
  }

  execute {
  }
}
