const FCL = require('@onflow/FCL');
const T = require('@onflow/types');
const PROCESS = require('process');
const UTILS = require('./utils')

const ConfigJson = require('../../'+UTILS.ConfigJsonFile)


async function Deposit(poolName, userAddr, amount) {
    const keyConfig = {
        account: userAddr,
        keyIndex: 0,
        privateKey: UTILS.CommonPrivateKey,
        SequenceNumber: 0
    };    
    const myAuth = UTILS.authFunc(keyConfig);
    FCL.config()

    var CODE = ConfigJson.Codes.Transactions.Deposit[poolName]
    const response = await FCL.send([
        FCL.transaction`
        ${CODE}
        `,
        FCL.args([
            FCL.arg(amount, T.UFix64)
        ]),
        FCL.proposer(myAuth),
        FCL.authorizations([myAuth]),
        FCL.payer(myAuth),
        FCL.limit(9999),
    ]);
    return await FCL.tx(response).onceSealed();
}

Deposit(PROCESS.argv[2], PROCESS.argv[3], PROCESS.argv[4])

// node scripts/testbot/api/js/deposit.js FUSD 0xe03daebed8ca0615 2.0