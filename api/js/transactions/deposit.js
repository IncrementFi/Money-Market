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
  const lowerTokenName = Utils.ConvertTokenNameToLowerName(tokenName)
  var lendingPoolContractName = "LendingPool"
  if(Config.network == "emulator") {
    // the same deployed contract name should be changed on emualtor.
    lendingPoolContractName = "LendingPool_" + tokenName
  }

  var CODE = TEMPLATE.replace(/FlowToken/g, tokenName).replace(/flowToken/g, lowerTokenName).replace(/LendingPool/g, lendingPoolContractName)
  console.log(CODE)

  Config.ConfigAddress()
  FCL.config().put("0x"+lendingPoolContractName, poolAddr)
  if(Config.network == "emulator") {
    FCL.config().put("0x"+tokenName, "0xf8d6e0586b0a20c7")
  }

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

//deposit(0.1, "0x192440c99cb17282", "FUSD")

module.exports = {
  deposit
}