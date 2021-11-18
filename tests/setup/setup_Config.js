import { deployContractByName, executeScript, mintFlow } from "flow-js-testing";
import { getConfigDeployerAddress } from "./setup_common";

/**
 * Deploy contract to the Config deployer account.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */ 
export const deployConfigContract = async () => {
    const ConfigDeployer = await getConfigDeployerAddress();
    // Mint some flow to deployer account for extra storage capacity.
    await mintFlow(ConfigDeployer, "100.0");

    return deployContractByName({
        to: ConfigDeployer,
        name: "Config"
    });
}

/**
 * 
 * @param {UFix64} f 
 * @returns f x 1e18 in UInt256
 */
export const UFix64ToScaledUInt256 = async (f) => {
    const ConfigDeployerAddress = await getConfigDeployerAddress();
    const code = `
        import Config from ${ConfigDeployerAddress}

        pub fun main(_ f: UFix64): UInt256 {
            return Config.UFix64ToScaledUInt256(f)
        }
    `;
    const args = [f];
    return executeScript({ code, args });
}

/**
 * 
 * @param {UInt256} s 
 * @returns s / 1e18 in UFix64
 */
export const ScaledUInt256ToUFix64 = async (s) => {
    const ConfigDeployerAddress = await getConfigDeployerAddress();
    const code = `
        import Config from ${ConfigDeployerAddress}

        pub fun main(_ s: UInt256): UFix64 {
            return Config.ScaledUInt256ToUFix64(s)
        }
    `;
    const args = [s];
    return executeScript({ code, args });
}

// Hardcoded test script due to javascript cannot correctly show number more than 21 decmials
export const UFix64MaxBackAndForth = async () => {
    const ConfigDeployerAddress = await getConfigDeployerAddress();
    const code = `
        import Config from ${ConfigDeployerAddress}

        pub fun main(): Bool {
            let fmax = UFix64.max
            let scaled_fmax = Config.UFix64ToScaledUInt256(fmax)
            let fmax_back = Config.ScaledUInt256ToUFix64(scaled_fmax)
            return fmax == fmax_back
        }
    `;
    const args = [];
    return executeScript({ code, args });
}