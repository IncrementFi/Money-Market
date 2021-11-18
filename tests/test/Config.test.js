import path from "path";
import { emulator, init, shallPass } from "flow-js-testing";
import { toUFix64 } from "../setup/setup_common";
import {
    deployConfigContract,
    UFix64ToScaledUInt256,
    ScaledUInt256ToUFix64,
    UFix64MaxBackAndForth
} from "../setup/setup_Config";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000);

describe("Config Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence");
        // Note: Use different port for different testsuites to run test simultaneously. 
        const port = 7003;
        await init(basePath, { port });
        return emulator.start(port, false);
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop();
    });

    it("Should deploy Config contract", async () => {
        await shallPass(deployConfigContract());
    });

    it("Test UFix64.min with 10^18 Scale should not truncate", async () => {
        await deployConfigContract();

        // UFix64.min to test no truncation
        let fmin = toUFix64(0.00000001)
        let scaled_fmin = await UFix64ToScaledUInt256(fmin)
        let fmin_back = await ScaledUInt256ToUFix64(scaled_fmin)
        expect(fmin).toBe(fmin_back)
        expect(scaled_fmin).toBe(0.00000001 * 1e18)
    });

    it("Test UFix64.max with 10^18 Scale should not overflow", async () => {
        await deployConfigContract();

        let equal = await UFix64MaxBackAndForth()
        expect(equal).toBe(true)
    });
});