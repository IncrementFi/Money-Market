
#### Setup

*  `npm -g install pm2`
*  `npm install`
*  `export PK=<your private key>`: The private key used for the off-chain reporter account (e.g. [0x8c1293886c086b0c](https://testnet.flowscan.org/account/0x8c1293886c086b0c))

  
  

### Config

*  `deployed.json` file:
Oracle contract and supported feeds deployment address and configuration. The update happenes whichever below conditions meet first.

	*  `windowSize`: e.g. 1200 - update once at most every 1200 seconds.
	*  `deviation`: e.g. 0.01 - update once Δ { marketData, lastSavedData } > 0.01.
  

*  `config.js` file:
	*  `network`: testnet for now.
	*  `heartbeat`: e.g. 60 * 1000 - check marketData every 60 seconds and update if necessary.

  

### Start SimpleOracle node

*  `pm2 start index.js` to run in daemon mode, or `node index.js` for a one-time run.