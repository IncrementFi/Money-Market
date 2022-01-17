const FCL = require('@onflow/FCL');
const T = require('@onflow/types');
const PROCESS = require('process');
const ChildProcess = require('child_process');
const UTILS = require('./utils')

const ConfigJson = require('../../'+UTILS.ConfigJsonFile)


async function Faucet(poolName, userAddr, amount) {
    console.log('faucet')
    if(poolName == 'FlowToken') {
        const cmd = 'flow transactions send ./cadence/transactions/Test/emulator_flow_transfer.cdc --arg Address:'+userAddr+' --arg UFix64:'+amount+' --signer emulator-account'
        console.log(cmd)
        ChildProcess.exec(cmd, function (error, stdout, stderr) {
            console.log(stdout)
            if (error !== null) {
                console.log('exec error: ' + error)
            }
        })
    } else {
        const keyConfig = {
            account: userAddr,
            keyIndex: 0,
            privateKey: UTILS.CommonPrivateKey,
            SequenceNumber: 0
        };    
        const myAuth = UTILS.authFunc(keyConfig);
        FCL.config()

        var CODE = ConfigJson.Codes.Transactions.Test['Mint'+poolName]
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
}

const res = Faucet(PROCESS.argv[2], PROCESS.argv[3], PROCESS.argv[4])
console.log(res)
// node tools/testbot/api/js/Faucet.js Apple 0xe03daebed8ca0615 200.0