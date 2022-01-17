const deployed = require('./deployed.json');

const network = 'testnet';

module.exports = {
  accessNode: deployed[network].accessNode,
  oracleContract: deployed[network].oracleContract,
  updaterAccount: deployed[network].updaterAccount,
  updaterKeyIndex: deployed[network].updaterKeyIndex,
  feeds: deployed[network].feeds,
  //coingeckoMegaFeeds: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=bitcoin,ethereum,flow,tether',
  coingeckoMegaFeeds: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=blocto-token,flow,tether',
  heartbeat: 60 * 1000,  // 60 seconds
};
