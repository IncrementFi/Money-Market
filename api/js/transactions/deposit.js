const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const Utils = require('../utils')
const Config = require('../config')

// Template code
var TEMPLATE = Utils.LoadCode('./cadence/transactions/User/user_deposit_template.cdc')
// import path -> 0xContractName
TEMPLATE = Utils.ReplaceContractPathToOxName(TEMPLATE)

//
function deposit(amount, poolAddr, tokenName) {
  // generate specific deposit transaction code for token
  var CODE = TEMPLATE.replace(/FlowToken/g, tokenName)
                     .replace(/flowToken/g, Utils.ConvertTokenNameToLowerName(tokenName))
                     .replace(/LendingPool/g, Config.GetLendingPoolContractName(tokenName))
  console.log(CODE)

  // config address mapping
  Config.CommonAddressMapping()
  Config.LendingPoolAddressMapping(poolAddr, tokenName)

  // send transaction
  const response = FCL.send([
    FCL.transaction`${CODE}`,
    FCL.args(
      [
        FCL.arg(amount.toString(), T.UFix64)
      ]
    ),
    //FCL.proposer(myAuth),
    //FCL.authorizations([myAuth]),
    //FCL.payer(myAuth),
    //FCL.limit(50),
  ]);
  return FCL.tx(response).onceSealed();
}

// for testing
//deposit(0.1, "0x192440c99cb17282", "FUSD")

module.exports = {
  deposit
}