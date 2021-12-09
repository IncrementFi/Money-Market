const assert = require('assert');
const fcl = require('@onflow/fcl');
const fetch = require('node-fetch');
const fs = require('fs');
const jp = require('jsonpath');
const path = require('path');
const t = require('@onflow/types');
const config = require('./config');
const utils = require('./utils');
const DeployConfigTestnet = require('../../deploy.config.testnet.json')

/// [Imported code start] - Related cadence transactions/scripts used in this script.
const uploadFeedDataTxCode = DeployConfigTestnet['Codes']['Transactions']['SimpleOracle']['UpdaterUploadFeedData']
const getFeedLatestResultScriptCode = DeployConfigTestnet['Codes']['Scripts']['GetSimpleOracleFeedLatestResult']
/// [Imported code end]

/// [DATA STRUCTURE start] - Local data structure used in this script.
// pool feeds' latest blockchain state, initialized on start or synced per heartbeat.
const states = [];
// keyConfig used in utils.authFunc
const keyConfig = {
  account: config.updaterAccount,
  keyIndex: config.updaterKeyIndex,
  privateKey: process.env.PK
};
const myAuth = utils.authFunc(keyConfig);
/// [DATA STRUCTURE end]

async function init(debug = true) {
  assert(process.env.PK && process.env.PK.length == 64,
    "Please export hex-formatted private key into env without leading '0x'");

  fcl
    .config()
    .put("accessNode.api", config.accessNode)

  for (let i = 0; i < config.feeds.length; i++) {
    let lastData = await getFeedLatestResult(config.oracleContract, config.feeds[i].address);
    let state = {
      id: config.feeds[i].id,
      address: config.feeds[i].address,
      windowSize: config.feeds[i].windowSize,
      deviation: config.feeds[i].deviation,
      selector: '$.' + config.feeds[i].id + '.usd',
      lastUpdated: parseInt(lastData[0]),
      lastPrice: lastData[1],
    }
    states.push(state);
  }
  if (debug) console.log('+++++ feeds inited ...');
}

async function sync() {
  for (let i = 0; i < config.feeds.length; i++) {
    let lastData = await getFeedLatestResult(config.oracleContract, config.feeds[i].address);
    states[i].lastUpdated = parseInt(lastData[0]);
    states[i].lastPrice = lastData[1];
  }
}

// Call cadence tx with private key exported in process.env
async function updateFeedData(pool, data) {
  const fclArgs = fcl.args([
    fcl.arg(pool, t.Address),
    fcl.arg(data.toFixed(8).toString(), t.UFix64)
  ]);
  const response = await fcl.send([
    fcl.transaction`
      ${uploadFeedDataTxCode}
    `,
    fclArgs,
    fcl.proposer(myAuth),
    fcl.authorizations([myAuth]),
    fcl.payer(myAuth),
    fcl.limit(50),
  ]);
  return await fcl.tx(response).onceSealed();
}

// Call cadence script
async function getFeedLatestResult(oracle, pool) {
  const fclArgs = fcl.args([
    fcl.arg(oracle, t.Address),
    fcl.arg(pool, t.Address)
  ]);
  const response = await fcl.send([
    fcl.script`
      ${getFeedLatestResultScriptCode}
    `,
    fclArgs
  ]);
  return await fcl.decode(response);
}

// Normalize selector string to equivalent format in case of special characters.
// e.g. '$.huobi-token.usd' => '$["huobi-token"]["usd"]'
function normalizeSelector(selector) {
  if (selector.indexOf('-') == -1) return selector;
  return selector
    .split('.')
    .map((val, i) => {
      if (i == 0) return val;
      return '[\"' + val + '\"]';
    })
    .join('');
}

// Sort response json by object keys. This is to normalize the jsonpath
// behavior between client software and this guardian bot.
function normalizeResponseJson(respJson) {
  return Object.keys(respJson).sort().reduce(function (result, key) {
    result[key] = respJson[key];
    return result;
  }, {});
}

async function queryCoingeckoFeedsData(debug = true) {
  let ret = [];
  let resp = await fetch(config.coingeckoMegaFeeds);
  let respJson = await resp.json();
  for (let i = 0; i < states.length; i++) {
    let data = jp.value(respJson, normalizeSelector(states[i].selector));
    ret.push({
      "feed": states[i].address, 
      "data": data
    });
    if (debug) {
      console.log(`+++++ coingecko data ${states[i].selector}: ${data}`);
    }
  }
  return ret;
}

// Returns true if p1 is beyond the upper/lower threshold of p0.
function deviated(p1, p0, threshold) {
  if (threshold < 0.0 || threshold > 1.0) return false;
  return p1 > (1.0 + threshold) * p0 || p1 < (1.0 - threshold) * p0;
}

/// Core function.
async function heartbeat(debug = true) {
  if (states.length == 0) {
    await init();
  } else {
    await sync();
  }

  let data = await queryCoingeckoFeedsData();
  for (let i = 0; i < states.length; i++) {
    let now = parseInt((new Date()).getTime() / 1000);
    let now_str = (new Date()).toTimeString().split(' ')[0];
    if (i == 0 && debug) console.log(`----- heartbeat ${now_str} ...`);
    let isDeviated = deviated(data[i].data, states[i].lastPrice, states[i].deviation);
    let isExpired = now > states[i].lastUpdated + states[i].windowSize;
    if (!isDeviated && !isExpired) {
      continue;
    } else if (isDeviated) {
      console.log(`+++++ Feed[${i}] ${states[i].selector} ${now_str} d(${data[i].data}), beyond last data (${states[i].lastPrice}) ±${states[i].deviation * 100}%, Deviation trigger`);
    } else if (isExpired) {
      console.log(`+++++ Feed[${i}] ${states[i].selector} ${now_str} d(${data[i].data}), last data (${states[i].lastPrice}) outdated, Timer trigger`);
    }
    let response = await updateFeedData(data[i].feed, data[i].data);
    console.log(
      "---- update response: ",
      response.events.filter(event => event.type.includes('SimpleOracle.DataUpdated'))
    );
  }
  setTimeout(heartbeat, config.heartbeat);
}

function errorHandler(e) {
  console.log(e);
  let now = (new Date()).toTimeString().split(' ')[0];
  console.log(`@@@@@ Error caught on ${now}, preparing for a restart...`);
  setTimeout(() => {
    process.exit(1)
  }, 3000)
}
  
process.on('uncaughtException',  errorHandler);
process.on('unhandledRejection', errorHandler);

heartbeat();
