const EC = require('elliptic').ec;
const ec = new EC('secp256k1');
const fcl = require('@onflow/fcl');
const sha3 = require('sha3');

function hashMsg(msg) {
    const sha = new sha3.SHA3(256);
    sha.update(Buffer.from(String(msg), "hex"));
    return sha.digest();
}
  
function produceSignature(privateKey, msg) {
    const key = ec.keyFromPrivate(Buffer.from(privateKey, "hex"));
    const sig = key.sign(hashMsg(msg));
    const n = 32;
    const r = sig.r.toArrayLike(Buffer, "be", n);
    const s = sig.s.toArrayLike(Buffer, "be", n);
    return Buffer.concat([r, s]).toString("hex");
};

// https://github.com/onflow/fcl-js/blob/master/docs/reference/api.md#authorization-function
// https://github.com/onflow/fcl-js/blob/master/packages/fcl/src/wallet-provider-spec/authorization-function.md
/**
    keyConfig = {
        account: flowAccountAddress,
        keyIndex: flowAccountKeyIndex,
        privateKey: privateKey_of_flowAccountKeyIndex
    }
 */
function authFunc(keyConfig) {
    return async function authorizationFunction(account) {
        // authorization function need to return an AccountObject
        return {
            ...account, // bunch of defaults in here, we want to overload some of them though
            tempId: `${keyConfig.account}-${keyConfig.keyIndex}`, // tempIds are more of an advanced topic, for 99% of the times where you know the address and keyId you will want it to be a unique string per that address and keyId
            addr: fcl.sansPrefix(keyConfig.account), // the address of the signatory, currently it needs to be without a prefix right now
            keyId: Number(keyConfig.keyIndex), // this is the keyId for the accounts registered key that will be used to sign, make extra sure this is a number and not a string
            signingFunction: async signable => {
                // Singing functions are passed a signable and need to return a composite signature
                // signable.message is a hex string of what needs to be signed.
                return {
                    addr: fcl.withPrefix(keyConfig.account), // needs to be the same as the account.addr but this time with a prefix, eventually they will both be with a prefix
                    keyId: Number(keyConfig.keyIndex), // needs to be the same as account.keyId, once again make sure its a number and not a string
                    signature: produceSignature(keyConfig.privateKey, signable.message), // this needs to be a hex string of the signature, where signable.message is the hex value that needs to be signed
                }
            }
        }
    }
}

module.exports = {
    hashMsg: hashMsg,
    produceSignature: produceSignature,
    authFunc: authFunc
}