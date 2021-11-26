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

export const configMarket = async (collateralFactor, borrowCap, isOpen, isMining) => {
    const comptrollerDeployer = await getComptrollerAddress()
    const lendingPoolDeployer = await getLendingPoolAddress()

    const name = "Comptroller/config_market"
    const signers = [comptrollerDeployer]
    const args = [lendingPoolDeployer, collateralFactor, borrowCap, isOpen, isMining]
    return sendTransaction({ name, args, signers })
}

export const queryUserLiquidity = async (userAddr) => {
    const auditAddr = await getComptrollerAddress()
    const name = "Query/query_user_position";
    const args = [userAddr, auditAddr];
    return executeScript({ name, args });
}

export const queryUserAllPools = async (userAddr) => {
    const auditAddr = await getComptrollerAddress()
    const name = "Query/query_user_all_pools";
    const args = [userAddr, auditAddr];
    return executeScript({ name, args });
}

