import { deployContractByName, getAccountAddress, executeScript, mintFlow, sendTransaction, getTemplate, getScriptCode } from "flow-js-testing"
import { getLendingPoolDeployerAddress, toUFix64 } from "./setup_common"
import { createInterestRateModel, } from "./setup_TwoSegmentsInterestRateModel";

export const getLendingPoolAddress = async () => { return await getLendingPoolDeployerAddress() }
export const getInterfacesAddress = async () => { return await getLendingPoolDeployerAddress() }
export const getConfigAddress = async () => { return await getLendingPoolDeployerAddress() }
export const getErrorAddress = async () => { return await getLendingPoolDeployerAddress() }
export const getInterestRateModelAddress = async () => { return await getLendingPoolDeployerAddress() }
export const getComptrollerAddress = async () => { return await getLendingPoolDeployerAddress() }
export const getSimpleOracleAddress = async () => { return await getLendingPoolDeployerAddress() }

/**
 * Deploy LendingPool and related Contracts.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployLendingPoolContract = async () => {
    const lendingPoolAddr = await getLendingPoolAddress()
    const interfacesAddr = await getInterfacesAddress()
    const configAddr = await getConfigAddress()
    const errorAddr = await getErrorAddress()
    const interestRateModel = await getInterestRateModelAddress()
    const comptrollerAddr = await getComptrollerAddress()
    const simpleOracleAddr = await getSimpleOracleAddress()
    // Mint some flow to deployer account for extra storage capacity.
    await mintFlow(lendingPoolAddr, "100.0")
    // Deploy indepencies & pool contracts.
    const addressMap = { LendingInterfaces: interfacesAddr, LendingConfig: configAddr, LendingError: errorAddr }
    await deployContractByName({ to: errorAddr, name: "LendingError" })
    await deployContractByName({ to: interfacesAddr, name: "LendingInterfaces" })
    await deployContractByName({ to: configAddr, name: "LendingConfig" })
    await deployContractByName({ to: simpleOracleAddr, name: "SimpleOracle", addressMap })
    await deployContractByName({ to: comptrollerAddr, name: "ComptrollerV1", addressMap })
    await deployContractByName({ to: interestRateModel, name: "TwoSegmentsInterestRateModel", addressMap });

    return deployContractByName({ to: lendingPoolAddr, name: "LendingPool", addressMap })
}

/**
 * Create underlying vault for LendingPool
 * @returns {Promise<*>}
 */
 export const preparePoolUnderlyingVault = async() => {
    const poolDeployer = await getLendingPoolAddress()
    const name = "Pool/prepare_template_for_pool"
    const signers = [poolDeployer]
    const args = []
    return sendTransaction({ name, args, signers })
}

export const initInterestRateModel = async() => {
    const interestAdmin = await getInterestRateModelAddress()
    const scaleFactor = 1e18
    return createInterestRateModel(
        interestAdmin,
        "TwoSegmentsInterestRateModelV1-test",
        12614400,
        0,
        5 * scaleFactor / 100,   // 0.05
        35 * scaleFactor / 100,  // 0.35
        80 * scaleFactor / 100   // 0.8
    )
}

export const initOracle = async() => {
    const admin = await getSimpleOracleAddress()
    // await createOracleResource()
    {
        const name = "Oracle/admin_create_oracle_resource";
        const signers = [admin];
        const args = [];
        await sendTransaction({ name, args, signers });
    }

    const updater = await getAccountAddress("feed-updater")
    // await updaterSetupAccount(updater)
    {
        const name = "Oracle/updater_setup_account";
        const signers = [updater];
        const args = [];
        await sendTransaction({ name, args, signers });
    }

    // await adminGrantUpdateRole(updater)
    {
        const name = "Oracle/admin_grant_update_role";
        const signers = [admin];
        const args = [updater];
        await sendTransaction({ name, args, signers });   
    }
    // await adminAddPriceFeed(testYToken1, 3)
    {
        const testYToken1 = await getLendingPoolAddress()
        const name = "Oracle/admin_add_price_feed";
        const signers = [admin];
        const args = [testYToken1, 3];
        await sendTransaction({ name, args, signers });    
    }
    return updateOraclePrice(toUFix64(35.5))
}

export const updateOraclePrice = async(price) => {
    const updater = await getAccountAddress("feed-updater")
    const testYToken1 = await getLendingPoolAddress()
    
    const name = "Oracle/updater_upload_feed_data";
    const signers = [updater];
    const args = [testYToken1, price];
    return sendTransaction({ name, args, signers });
}

export const initComptroller = async () => {
    const oracleAddr = await getSimpleOracleAddress()
    const comptrollerDeployer = await getComptrollerAddress()
    const name = "Comptroller/init_comptroller"
    const signers = [comptrollerDeployer]
    const args = [oracleAddr, 0.5]
    return sendTransaction({ name, args, signers })
}

export const initPool = async (reserveFactor, poolSeizeShare) => {
    const lendingPoolDeployer = await getLendingPoolAddress()
    const comptrollerDeployer = await getComptrollerAddress()
    const rateModelDeployer = await getInterfacesAddress()

    const name = "Pool/init_pool_template"
    const signers = [lendingPoolDeployer]
    const args = [rateModelDeployer, comptrollerDeployer, reserveFactor, poolSeizeShare]
    return sendTransaction({ name, args, signers })
}

export const addMarket = async (liquidationPenalty, collateralFactor, borrowCap, isOpen, isMining) => {
    const comptrollerDeployer = await getComptrollerAddress()
    const lendingPoolDeployer = await getLendingPoolAddress()

    const name = "Comptroller/add_market"
    const signers = [comptrollerDeployer]
    const args = [lendingPoolDeployer, liquidationPenalty, collateralFactor, borrowCap, isOpen, isMining]
    return sendTransaction({ name, args, signers })
}