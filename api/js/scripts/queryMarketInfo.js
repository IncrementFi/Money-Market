const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const ConfigJson = require('../../../deploy.config.emulator.json')

// load contract codes
var CODE = ConfigJson.Codes.Scripts["QueryMarketInfo"]
console.log(CODE)
// import path -> 0xContractName
// CODE = Utils.ReplaceContractPathToOxName(CODE)

function queryMarketInfo(poolAddr, auditAddr) {
  if (!auditAddr) return Promise.resolve(false);
  
  //Config.CommonAddressMapping()

  return FCL.send(
    [
      FCL.script(CODE),
      FCL.args(
        [
          FCL.arg(poolAddr, T.Address),
          FCL.arg(auditAddr, T.Address)
        ]
      )
    ]).then(FCL.decode);
}

queryMarketInfo("0x192440c99cb17282", "0xf8d6e0586b0a20c7")

module.exports = {
  queryMarketInfo
}