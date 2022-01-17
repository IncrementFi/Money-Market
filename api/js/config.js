const address = require('./address.json');
const FCL = require('@onflow/fcl');

const network = 'emulator'; // testnet, mainnet

function CommonAddressMapping() {
  FCL.config()
    .put("0xInterfaces", address["LendingInterfaces"][network])
    .put("0xConfig", address["LendingConfig"][network])
    .put("0xFungibleToken", address["FungibleToken"][network])
    .put("0xFUSD", address["FUSD"][network])
  
}

function LendingPoolAddressMapping(poolAddr, tokenName) {
  const lendingPoolContractName = GetLendingPoolContractName(tokenName)

  FCL.config().
    put("0x"+lendingPoolContractName, poolAddr)
  
  if(network == "emulator") {
    // used for fake tokens on emulator
    FCL.config().put("0x"+tokenName, "0xf8d6e0586b0a20c7")
  }
}

function GetLendingPoolContractName(tokenName) {
  var lendingPoolContractName = "LendingPool"
  if(network == "emulator") {
    // the same deployed contract name should be changed on emualtor.
    lendingPoolContractName = "LendingPool_" + tokenName
  }
  return lendingPoolContractName
}


module.exports = {
  CommonAddressMapping,
  LendingPoolAddressMapping,
  GetLendingPoolContractName
};