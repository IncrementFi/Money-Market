import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getInterestRateModelDeployerAddress, getInterfaceDeployerAddress } from "./setup_common";

/**
 * Deploy InterestRateModel Contract to the specific deployer (i.e. admin) account.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */ 
export const deployInterestRateModel = async () => {
    const interestRateModelDeployer = await getInterestRateModelDeployerAddress();
    // Mint some flow to deployer account for extra storage capacity.
    await mintFlow(interestRateModelDeployer, "100.0");

    await deployContractByName({
        to: interestRateModelDeployer,
        name: "InterestRateModelInterface"
    });

    const addressMap = { InterestRateModelInterface: interestRateModelDeployer };
    return deployContractByName({
        to: interestRateModelDeployer,
        name: "TwoSegmentsInterestRateModel",
        addressMap
    });
}

/**
 * Create new InterestRateModel resource and setup necessary Capabilities.
 * @param {string} modelName - e.g. "TwoSegmentsInterestRateModel"
 * @param {UInt64} blocksPerYear - 1s avg blocktime for testnet (31536000 blocks / year), 2.5s avg blocktime for mainnet (12614400 blocks / year).
 * @param {UFix64} zeroUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 0%, e.g. 0.0 (0%)
 * @param {UFix64} criticalUtilInterestRatePerYear - Borrow interest rate per year when utilization rate hits the critical point, e.g. 0.0 (0%) e.g. 0.05 (5%)
 * @param {UFix64} fullUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 100%, e.g. 0.35 (35%)
 * @param {UFix64} criticalUtilPoint - The critical utilization point beyond which the interest rate jumps (i.e. two-segments interest model), e.g. 0.8 (80%) 
 * @returns {Promise<*>}
 */
export const createInterestRateModel = async (
    modelName,
    blocksPerYear,
    zeroUtilInterestRatePerYear,
    criticalUtilInterestRatePerYear,
    fullUtilInterestRatePerYear,
    criticalUtilPoint
) => {
    const deployer = await getInterestRateModelDeployerAddress();
    const name = "InterestRateModel/create_interest_rate_model";
	const signers = [deployer];
    const args = [modelName, blocksPerYear, zeroUtilInterestRatePerYear, criticalUtilInterestRatePerYear, fullUtilInterestRatePerYear, criticalUtilPoint];
    return sendTransaction({ name, args, signers });
}

export const updateInterestRateModelParams = async (
    newBlocksPerYear,
    newZeroUtilInterestRatePerYear,
    newCriticalUtilInterestRatePerYear,
    newFullUtilInterestRatePerYear,
    newCriticalUtilPoint
) => {
    const deployer = await getInterestRateModelDeployerAddress();
    const name = "InterestRateModel/update_model_params";
	const signers = [deployer];
    const args = [newBlocksPerYear, newZeroUtilInterestRatePerYear, newCriticalUtilInterestRatePerYear, newFullUtilInterestRatePerYear, newCriticalUtilPoint];
    return sendTransaction({ name, args, signers });
}

/**
* @returns {String: AnyStruct}
*/
export const getInterestRateModelParams = async () => {
    const modelAddress = await getInterestRateModelDeployerAddress();
    const name = "InterestRateModel/get_model_params";
    const args = [modelAddress];
    return executeScript({ name, args });
}