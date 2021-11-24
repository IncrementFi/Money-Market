import { deployContractByName, getAccountAddress, executeScript, mintFlow, sendTransaction, getTemplate, getScriptCode } from "flow-js-testing"
import { getLendingPoolDeployerAddress } from "./setup_common"
import { createInterestRateModel, } from "./setup_TwoSegmentsInterestRateModel";

import {
    getLendingPoolAddress,
    getInterfacesAddress,
    getConfigAddress,
    getInterestRateModelAddress,
    getComptrollerAddress,
    getSimpleOracleAddress,    
} from "../setup/setup_Deployment";

export const queryPoolInfo = async () => {
    const poolAddr = await getLendingPoolAddress()
    const auditAddr = await getComptrollerAddress()
    
    const name = "Query/query_market_info"
    const args = [poolAddr, auditAddr]
    return executeScript({ name, args })
}

export const queryFlowTokenPoolState = async() => {
    const name = "Test/query_pool_state_template"
    const args = []
    return executeScript({ name, args })
}

export const queryUserPoolState = async(userAddr) => {
    const poolAddr = await getLendingPoolAddress()
    const name = "Test/query_user_pool_state"
    const args = [poolAddr, userAddr]
    return executeScript({ name, args })
}

export const nextBlock = async() => {
    const auditAddr = await getComptrollerAddress()

    const name = "Test/test_next_block"
    const signers = [auditAddr]
    const args = []
    return sendTransaction({ name, args, signers })
}

export const queryCurrentBlockId = async () => {
    const code = `
        pub fun main(): UInt256 {
            return UInt256(getCurrentBlock().height)
        }
    `;
    const args = [];
    return executeScript({ code, args });
}

/**
 * 
 * @returns {Promise<*>}
 */
 export const supply = async (userAddr, supplyAmount) => {
    const name = "User/user_deposit_template"
    const signers = [userAddr]
    const args = [supplyAmount]
    return sendTransaction({ name, args, signers })
}

/**
 * 
 * @returns {Promise<*>}
 */
 export const redeem = async (userAddr, redeemAmount) => {
    const name = "User/user_redeem_template"
    const signers = [userAddr]
    const args = [redeemAmount]
    return sendTransaction({ name, args, signers })
}
