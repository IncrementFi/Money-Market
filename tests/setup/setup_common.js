import { getAccountAddress } from "flow-js-testing";

const UFIX64_PRECISION = 8;

// UFix64 values shall be always passed as strings
export const toUFix64 = (value) => value.toFixed(UFIX64_PRECISION);

export const getInterestRateModelDeployerAddress = async () => getAccountAddress("InterestRateModelDeployer");
export const getOracleDeployerAddress = async () => getAccountAddress("OracleDeployer");
export const getAuditorDeployerAddress = async () => getAccountAddress("AuditorDeployer");
export const getYFlowDeployerAddress = async () => getAccountAddress("yFlowDeployer");
export const getYFusdDeployerAddress = async () => getAccountAddress("yFusdDeployer");