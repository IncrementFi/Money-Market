const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const ConfigJson = require('../../../deploy.config.emulator.json')

// load contract codes
var CODE = ConfigJson.Codes.Scripts["QueryAllMarkets"]
console.log(CODE)

function queryAllMarkets(auditAddr) {
  if (!auditAddr) return Promise.resolve(false);

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

queryAllMarkets(ConfigJson["ContractAddress"]["ComptrollerV1"])

module.exports = {
  queryAllMarkets
}