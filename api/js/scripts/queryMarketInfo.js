const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const Utils = require('../utils')
const Config = require('../config')

// load contract codes
var CODE = Utils.LoadCode('./cadence/scripts/Query/query_market_info.cdc')
// import path -> 0xContractName
CODE = Utils.ReplaceContractPathToOxName(CODE)

function queryMarketInfo(poolAddr, auditAddr) {
  if (!auditAddr) return Promise.resolve(false);
  
  Config.ConfigAddress()

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

//queryMarketInfo("0x192440c99cb17282", "0xf8d6e0586b0a20c7")

module.exports = {
  queryMarketInfo
}