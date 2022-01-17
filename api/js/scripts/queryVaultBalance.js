const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const Utils = require('../utils');
const ConfigJson = require('../../../deploy.config.emulator.json')

// load contract codes
var CODE = ConfigJson.Codes.Scripts['QueryVaultBalance']
// import path -> 0xContractName
// CODE = Utils.ReplaceContractPathToOxName(CODE)

function queryVaultBalance(userAddr, tokenName) {
  if (!userAddr) return Promise.resolve(false);
  
  // LendingConfig.CommonAddressMapping()

  const pathPara = {
    "domain": "public",
    "identifier": Utils.ConvertTokenNameToLowerName(tokenName)+"Balance"
  }

  return FCL.send(
    [
      FCL.script(CODE),
      FCL.args(
        [
          FCL.arg(userAddr, T.Address),
          FCL.arg(pathPara, T.Path)
        ]
      )
    ]).then(FCL.decode);
}

queryVaultBalance("0xe03daebed8ca0615", "Apple")

module.exports = {
  queryVaultBalance
}