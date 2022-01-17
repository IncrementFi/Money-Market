const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const ConfigJson = require('../../../deploy.config.emulator.json')

// load contract codes
var CODE = ConfigJson.Codes.Scripts['QueryUserAllPools']
// import path -> 0xContractName
// CODE = Utils.ReplaceContractPathToOxName(CODE)

function queryUserAllPools(userAddr, auditAddr) {
  if (!auditAddr) return Promise.resolve(false);
  
  // LendingConfig.CommonAddressMapping()

  return FCL.send(
    [
      FCL.script(CODE),
      FCL.args(
        [
          FCL.arg(userAddr, T.Address),
          FCL.arg(auditAddr, T.Address)
        ]
      )
    ]).then(FCL.decode);
}

queryUserAllPools("0xe03daebed8ca0615", "0xf8d6e0586b0a20c7")

module.exports = {
  queryUserAllPools
}