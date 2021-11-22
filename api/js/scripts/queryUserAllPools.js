const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const Utils = require('../utils')
const Config = require('../config')

// load contract codes
var CODE = Utils.LoadCode('./cadence/scripts/Query/query_user_all_pools.cdc')
// import path -> 0xContractName
CODE = Utils.ReplaceContractPathToOxName(CODE)

function queryUserAllPools(userAddr, auditAddr) {
  if (!auditAddr) return Promise.resolve(false);
  
  Config.CommonAddressMapping()

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

//queryUserAllPools("0xe03daebed8ca0615", "0xf8d6e0586b0a20c7")

module.exports = {
  queryUserAllPools
}