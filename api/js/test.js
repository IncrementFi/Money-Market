//import { send, decode, script, args, arg, cdc } from '@onflow/fcl';

//import * as fcl from '@onflow/fcl';
const FCL = require('@onflow/fcl');

//import { ReplaceCadenceImport } from '@/config/cdc.util';
const T = require('@onflow/types');
const CODE = FCL.cdc(
  `
    import Interfaces from 0xInterfaces
    import Config from 0xConfig
    pub fun main(comptrollerAddr: Address): [Address] {
        let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
        let poolAddrs = comptrollerRef.getAllMarkets()
        log(poolAddrs)
        return poolAddrs
    }
  `
);

export function queryAllMarkets(auditAddr) {
  FCL.config()
    .put("0xInterfaces", "0xf8d6e0586b0a20c7")
    .put("0xConfig", "0xf8d6e0586b0a20c7")
  if (!auditAddr) return Promise.resolve(false);
  return FCL.send([FCL.script(CODE), FCL.args([FCL.arg(auditAddr, T.Address)])]).then(FCL.decode);
}


const utils = require('../../scripts/simple_oracle/utils');

const keyConfig = {
  account: "0xf8d6e0586b0a20c7",
  keyIndex: 0,
  privateKey: "b15fd31d0847f028abdb617da70a3f7a7e63ae8fdd63882cb47c54b6bec2605f"
};

const myAuth = utils.authFunc(keyConfig);
queryAllMarkets("0xf8d6e0586b0a20c7")