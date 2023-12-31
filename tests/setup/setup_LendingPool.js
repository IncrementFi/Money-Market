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
} from "./setup_Deployment";

export const queryPoolInfo = async () => {
    const poolAddr = await getLendingPoolAddress()
    const auditAddr = await getComptrollerAddress()
    
    const name = "Query/query_market_info"
    const args = [poolAddr, auditAddr]
    return executeScript({ name, args })
}

export const queryUserPosition = async (userAddr) => {
    const auditAddr = await getComptrollerAddress()
    
    const name = "Query/query_user_position"
    const args = [userAddr, auditAddr]
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

export const queryFlowTokenInterestRate = async () => {
    const modelAddr = await getInterestRateModelAddress()
    const name = "Test/query_interest_rates_template";
    const args = [modelAddr];
    return executeScript({ name, args });
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

/**
 * 
 * @returns {Promise<*>}
 */
 export const borrow = async (userAddr, borrowAmount) => {
    const name = "User/user_borrow_template"
    const signers = [userAddr]
    const args = [borrowAmount]
    return sendTransaction({ name, args, signers })
}

/**
 * 
 * @returns {Promise<*>}
 */
 export const repay = async (userAddr, repayAmount) => {
    const name = "User/user_repay_template"
    const signers = [userAddr]
    const args = [repayAmount]
    return sendTransaction({ name, args, signers })
}

/**
 * 
 * @returns {Promise<*>}
 */
 export const liquidate = async (liquidatorAddr, borrowerAddr, seizePoolAddr, liquidateAmount) => {
    const name = "User/user_liquidate_template"
    const signers = [liquidatorAddr]
    const args = [liquidateAmount, borrowerAddr, seizePoolAddr]
    return sendTransaction({ name, args, signers })
}