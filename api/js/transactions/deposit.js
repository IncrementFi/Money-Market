const FCL = require('@onflow/fcl');
const T = require('@onflow/types');
const ConfigJson = require('../../../deploy.config.emulator.json')

// Template code

var TEMPLATE = Utils.LoadCode('./cadence/transactions/User/user_deposit_template.cdc')
// import path -> 0xContractName
TEMPLATE = Utils.ReplaceContractPathToOxName(TEMPLATE)

//
function deposit(amount, poolName) {
  var CODE = ConfigJson.Codes.Transactions.Deposit[poolName]
  console.log(CODE)

  // send transaction
  /*
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
  */
}

// for testing
// deposit(0.1, "FlowToken")

module.exports = {
  deposit
}