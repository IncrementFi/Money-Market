import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getInterestRateModelDeployerAddress } from "./setup_common";

export const getInterestRateModelAdmin = async () => {
    const admin = await getInterestRateModelDeployerAddress();
    return admin;
}

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
        name: "Interfaces"
    });

    // Must use deployed InterestRateModelInterface.
    const addressMap = { Interfaces: interestRateModelDeployer };
    return deployContractByName({
        to: interestRateModelDeployer,
        name: "TwoSegmentsInterestRateModel",
        addressMap
    });
}

/**
 * Create new InterestRateModel resource and setup necessary Capabilities.
 * @param {Address} signer - Transaction proposer. Only contract admin could create model resource successfully.
 * @param {string} modelName - e.g. "TwoSegmentsInterestRateModel"
 * @param {UInt64} blocksPerYear - 1s avg blocktime for testnet (31536000 blocks / year), 2.5s avg blocktime for mainnet (12614400 blocks / year).
 * @param {UFix64} zeroUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 0%, e.g. 0.0 (0%)
 * @param {UFix64} criticalUtilInterestRatePerYear - Borrow interest rate per year when utilization rate hits the critical point, e.g. 0.05 (5%)
 * @param {UFix64} fullUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 100%, e.g. 0.35 (35%)
 * @param {UFix64} criticalUtilPoint - The critical utilization point beyond which the interest rate jumps (i.e. two-segments interest model), e.g. 0.8 (80%) 
 * @returns {Promise<*>}
 */
export const createInterestRateModel = async (
    signer,
    modelName,
    blocksPerYear,
    zeroUtilInterestRatePerYear,
    criticalUtilInterestRatePerYear,
    fullUtilInterestRatePerYear,
    criticalUtilPoint
) => {
    const name = "InterestRateModel/create_interest_rate_model";
    const signers = [signer];
    const args = [modelName, blocksPerYear, zeroUtilInterestRatePerYear, criticalUtilInterestRatePerYear, fullUtilInterestRatePerYear, criticalUtilPoint];
    return sendTransaction({ name, args, signers });
}

/**
 * @param {Address} signer - Only contract admin could update model params successfully.
 * @param {UInt64} newBlocksPerYear
 * @param {UFix64} newZeroUtilInterestRatePerYear
 * @param {UFix64} newCriticalUtilInterestRatePerYear
 * @param {UFix64} newFullUtilInterestRatePerYear
 * @param {UFix64} newCriticalUtilPoint
 * @returns {Promise<*>}
 */
export const updateInterestRateModelParams = async (
    signer,
    newBlocksPerYear,
    newZeroUtilInterestRatePerYear,
    newCriticalUtilInterestRatePerYear,
    newFullUtilInterestRatePerYear,
    newCriticalUtilPoint
) => {
    const name = "InterestRateModel/update_model_params";
    const signers = [signer];
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