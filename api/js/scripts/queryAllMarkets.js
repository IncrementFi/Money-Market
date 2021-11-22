const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const Utils = require('../utils')
const Config = require('../config')

// load contract codes
var CODE = Utils.LoadCode('./cadence/scripts/Query/query_all_markets.cdc')
// import path -> 0xContractName
CODE = Utils.ReplaceContractPathToOxName(CODE)

function queryAllMarkets(auditAddr) {
  if (!auditAddr) return Promise.resolve(false);
  
  Config.ConfigAddress()

  return FCL.send(
    [
      FCL.script(CODE),
      FCL.args(
        [
          FCL.arg(auditAddr, T.Address)
        ]
      )
    ]).then(FCL.decode);
}

module.exports = {
  queryAllMarkets
}