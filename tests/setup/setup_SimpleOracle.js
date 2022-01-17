import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getOracleDeployerAddress } from "./setup_common";

export const getOracleContractAddress = async () => {
    const admin = await getOracleDeployerAddress();
    return admin;
}

/**
 * Deploy SimpleOracle Contract to the specific deployer (i.e. admin) account.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */ 
 export const deploySimpleOracleContract = async () => {
    const oracleDeployer = await getOracleDeployerAddress();
    // Mint some flow to deployer account for extra storage capacity.
    await mintFlow(oracleDeployer, "100.0");

    await deployContractByName({
        to: oracleDeployer,
        name: "LendingInterfaces"
    });

    // Must use deployed OracleInterface.
    const addressMap = { LendingInterfaces: oracleDeployer };
    return deployContractByName({
        to: oracleDeployer,
        name: "SimpleOracle",
        addressMap
    });
}

export const createOracleResource = async () => {
    const admin = await getOracleDeployerAddress();
    const name = "Oracle/admin_create_oracle_resource";
    const signers = [admin];
    const args = [];
    return sendTransaction({ name, args, signers });
}

/**
 * @param {Address} pool - Price feed to add.
 * @param {Int} maxCapacity - RingBuffer size for the added feed.
 * @returns {Promise<*>}
 */
export const adminAddPriceFeed = async (pool, maxCapacity) => {
    const admin = await getOracleDeployerAddress();
    const name = "Oracle/admin_add_price_feed";
    const signers = [admin];
    const args = [pool, maxCapacity];
    return sendTransaction({ name, args, signers });
}

export const adminRemovePriceFeed = async (pool) => {
    const admin = await getOracleDeployerAddress();
    const name = "Oracle/admin_remove_price_feed";
    const signers = [admin];
    const args = [pool];
    return sendTransaction({ name, args, signers });
}

/**
 * @param {Address} updater - The account to be granted with update data capability.
 * @returns {Promise<*>}
 */
export const adminGrantUpdateRole = async (updater) => {
    const admin = await getOracleDeployerAddress();
    const name = "Oracle/admin_grant_update_role";
    const signers = [admin];
    const args = [updater];
    return sendTransaction({ name, args, signers });
}

/**
 * @param {(Private) CapabilityPath} updaterCapPath - The update capability path admin wants to revoke.
 * @returns {Promise<*>}
 */
export const adminRevokeUpdateRole = async () => {
    const admin = await getOracleDeployerAddress();
    const name = "Oracle/admin_revoke_update_role";
    const signers = [admin];
    const args = [];
    return sendTransaction({ name, args, signers });
}

/**
 * 
 * @param {Address} oracleAddress - Deployment address of oracle contract
 * @returns {[Address]} - pool address array of supported data feeds 
 */
export const getSupportedDataFeeds = async (oracleAddress) => {
    const name = "Oracle/get_supported_data_feeds";
    const args = [oracleAddress];
    return executeScript({ name, args });
}

/**
 * 
 * @param {Address} oracleAddress 
 * @param {Address} pool 
 * @returns {[UFix64]} - pool's data feed's latest result in form of [timestamp, data]
 */
export const getFeedLatestResult = async (oracleAddress, pool) => {
    const name = "Oracle/get_feed_latest_result";
    const args = [oracleAddress, pool];
    return executeScript({ name, args });
}

/**
 * Check whether the updater has been setup and granted with updateCapability or not.
 * @param {Address} updater
 * @returns {Bool}
 */
 export const checkUpdaterSetupStatus = async (updater) => {
    const name = "Oracle/check_updater_setup";
    const args = [updater];
    return executeScript({ name, args });
}

/**
 * @param {Address} updater - The updater account to setup before receiving updaterCapability from admin.
 * @returns {Promise<*>}
 */
export const updaterSetupAccount = async (updater) => {
    const name = "Oracle/updater_setup_account";
    const signers = [updater];
    const args = [];
    return sendTransaction({ name, args, signers });
}

/**
 * @param {Address} updater - The updater account with granted updateCapability to upload data point on-chain.
 * @param {Address} pool - The data feed to upload data with.
 * @param {UFix64} data - The raw priceData point.
 * @returns {Promise<*>}
 */
export const updaterUpdateData = async (updater, pool, data) => {
    const name = "Oracle/updater_upload_feed_data";
    const signers = [updater];
    const args = [pool, data];
    return sendTransaction({ name, args, signers });
}