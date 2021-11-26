import path from "path";
import { emulator, init, mintFlow, getAccountAddress, shallPass, shallRevert } from "flow-js-testing";
import { toUFix64 } from "../setup/setup_common";
import {
    deployLendingPoolContract,
    //
    preparePoolUnderlyingVault,
    initInterestRateModel,
    initOracle,
    initComptroller,
    initPool,
    addMarket,
} from "../setup/setup_Deployment";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000)

describe("LendingPool Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence")
        // Note: Use different port for different testsuites to run test simultaneously. 
        const port = 7004
        await init(basePath, { port })
        return emulator.start(port, false)
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop()
    });
    it("Should prepare underlying vault before deploying LendingPool", async () => {
        await shallRevert(deployLendingPoolContract())
        await shallPass(preparePoolUnderlyingVault())
    });
    it("Should deploy LendingPool & related contracts successfully", async () => {
        await preparePoolUnderlyingVault()
        await shallPass(deployLendingPoolContract())
    });

    it("Contracts initialization.", async () => {
        await preparePoolUnderlyingVault()
        await deployLendingPoolContract()

        await shallPass(initInterestRateModel())

        await shallPass(initOracle())
        
        await shallPass(initComptroller())

        await shallPass(initPool(0.01, 0.028))

        await shallPass(addMarket(0.75, 10000.0, true, true))
    });
    
    
});