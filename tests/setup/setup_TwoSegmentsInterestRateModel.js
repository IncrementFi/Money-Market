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
 * @param {string}  modelName - e.g. "TwoSegmentsInterestRateModel"
 * @param {UInt256} blocksPerYear - 1s avg blocktime for testnet (31536000 blocks / year), 2.5s avg blocktime for mainnet (12614400 blocks / year).
 * @param {UInt256} scaleFactor - Scale factor applied to fixed point number calculation to get rid of truncation accuracy loss, e.g. 1e18
 * @param {UInt256} scaledZeroUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 0%, e.g. 0.0 x 1e18 (0%)
 * @param {UInt256} scaledCriticalUtilInterestRatePerYear - Borrow interest rate per year when utilization rate hits the critical point, e.g. 0.05 x 1e18 (5%)
 * @param {UInt256} scaledFullUtilInterestRatePerYear - Borrow interest rate per year when utilization rate is 100%, e.g. 0.35 x 1e18 (35%)
 * @param {UInt256} scaledCriticalUtilPoint - The critical utilization point beyond which the interest rate jumps (i.e. two-segments interest model), e.g. 0.8 x 1e18 (80%) 
 * @returns {Promise<*>}
 */
export const createInterestRateModel = async (
    signer,
    modelName,
    blocksPerYear,
    scaleFactor,
    scaledZeroUtilInterestRatePerYear,
    scaledCriticalUtilInterestRatePerYear,
    scaledFullUtilInterestRatePerYear,
    scaledCriticalUtilPoint
) => {
    const name = "InterestRateModel/create_interest_rate_model";
    const signers = [signer];
    const args = [modelName, blocksPerYear, scaleFactor, scaledZeroUtilInterestRatePerYear, scaledCriticalUtilInterestRatePerYear, scaledFullUtilInterestRatePerYear, scaledCriticalUtilPoint];
    return sendTransaction({ name, args, signers });
}

/**
 * @param {Address} signer - Only contract admin could update model params successfully.
 * @param {UInt256} newBlocksPerYear
 * @param {UInt256} newScaleFactor
 * @param {UInt256} newScaledZeroUtilInterestRatePerYear
 * @param {UInt256} newScaledCriticalUtilInterestRatePerYear
 * @param {UInt256} newScaledFullUtilInterestRatePerYear
 * @param {UInt256} newScaledCriticalUtilPoint
 * @returns {Promise<*>}
 */
export const updateInterestRateModelParams = async (
    signer,
    newBlocksPerYear,
    newScaleFactor,
    newScaledZeroUtilInterestRatePerYear,
    newScaledCriticalUtilInterestRatePerYear,
    newScaledFullUtilInterestRatePerYear,
    newScaledCriticalUtilPoint
) => {
    const name = "InterestRateModel/update_model_params";
    const signers = [signer];
    const args = [newBlocksPerYear, newScaleFactor, newScaledZeroUtilInterestRatePerYear, newScaledCriticalUtilInterestRatePerYear, newScaledFullUtilInterestRatePerYear, newScaledCriticalUtilPoint];
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

/**
 * 
 * @param {UInt256} cash pool cash scaled up by scaleFactor (1e18)
 * @param {UInt256} borrows pool borrows scaled by scaleFactor (1e18)
 * @param {UInt256} reserves pool reserves scaled up by scaleFactor (1e18)
 * @returns (scaled array) [capitalUtilizationRate, borrowInterestRate, supplyInterestRate]
 */
export const getInterestRateData = async (
    cash,
    borrows,
    reserves
) => {
    const modelAddress = await getInterestRateModelDeployerAddress();
    const name = "InterestRateModel/get_interest_rates";
    const args = [modelAddress, cash, borrows, reserves];
    return executeScript({ name, args });
}