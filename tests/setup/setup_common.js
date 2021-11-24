import { getAccountAddress } from "flow-js-testing";

const UFIX64_PRECISION = 8;

// UFix64 values shall be always passed as strings
export const toUFix64 = (value) => value.toFixed(UFIX64_PRECISION);
export const ScaleFactor = 1e18

export const getConfigDeployerAddress = async () => getAccountAddress("ConfigDeployer");
export const getInterestRateModelDeployerAddress = async () => getAccountAddress("InterestRateModelDeployer");
export const getOracleDeployerAddress = async () => getAccountAddress("LendingPoolDeployer");
export const getLendingPoolDeployerAddress = async () => getAccountAddress("LendingPoolDeployer");
