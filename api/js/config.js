const address = require('./address.json');
const FCL = require('@onflow/fcl');

const network = 'emulator'; // testnet, mainnet

function ConfigAddress() {
  FCL.config()
    .put("0xInterfaces", address["Interfaces"][network])
    .put("0xConfig", address["Config"][network])
    .put("0xFungibleToken", address["FungibleToken"][network])
    .put("0xFUSD", address["FUSD"][network])
  
}


module.exports = {
  ConfigAddress,
  network
};