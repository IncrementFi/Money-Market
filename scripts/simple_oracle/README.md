
#### Setup

*  `npm -g install pm2`
*  `npm install`
*  `export PK=3e173ab34b4629ee8e16ee95a6aacb5f088fc95e53ba28ef0f528bf8bcce51ec`: The private key used for the off-chain reporter account (Given private key is for testnet updater account [0xed8eaa1512ba24aa](https://testnet.flowscan.org/account/0xed8eaa1512ba24aa))

  
  

### Config

*  `deployed.json` file:
Oracle contract and supported feeds deployment address and configuration. The update happenes whichever below conditions meet first.

	*  `windowSize`: e.g. 1200 - update once at most every 1200 seconds.
	*  `deviation`: e.g. 0.01 - update once Δ { marketData, lastSavedData } > 0.01.
  

*  `config.js` file:
	*  `network`: testnet for now.
	*  `heartbeat`: e.g. 60 * 1000 - check marketData every 60 seconds and update if necessary.

  

### Start SimpleOracle node

* start email monitor
    config the pm2-health as https://stackoverflow.com/questions/60394821/pm2-health-can-i-use-pm2-health-module-for-sending-email-alerts-notifications
    `pm2 restart pm2-health`

*  `pm2 start simple_oracle.js --exp-backoff-restart-delay=10000` to run in daemon mode, or `node index.js` for a one-time run.
