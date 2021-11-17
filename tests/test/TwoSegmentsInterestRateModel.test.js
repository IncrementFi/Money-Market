import path from "path";
import { emulator, init, getAccountAddress, shallPass, shallRevert } from "flow-js-testing";
import { toUFix64 } from "../setup/setup_common";
import {
    getInterestRateModelAdmin,
    deployInterestRateModel,
    createInterestRateModel,
    updateInterestRateModelParams,
    getInterestRateModelParams,
} from "../setup/setup_TwoSegmentsInterestRateModel";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000);

describe("InterestRateModel Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence");
        // Note: Use different port for different testsuites to run test simultaneously.
        const port = 7001;
        await init(basePath, { port });
        return emulator.start(port, false);
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop();
    });

    it("Should deploy InterestRateModel Contract", async () => {
        await shallPass(deployInterestRateModel());
    });

    it("Non-admin should not create InterestRateModel resource", async () => {
        await deployInterestRateModel();

        // Not contract admin
        const alice = await getAccountAddress("Alice");
        await shallRevert(createInterestRateModel(
            alice,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            toUFix64(0.0),
            toUFix64(0.05),
            toUFix64(0.35),
            toUFix64(0.8)
        ));
    });

    it("Create InterestRateModel Resource then check model params should match", async () => {
        await deployInterestRateModel();

        const admin = await getInterestRateModelAdmin();
        const createTxResult = await shallPass(createInterestRateModel(
            admin,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            toUFix64(0.0),
            toUFix64(0.05),
            toUFix64(0.35),
            toUFix64(0.8)
        ));
        const modelParams = await getInterestRateModelParams();
        const eventData = createTxResult.events[0].data;
        console.log(eventData)
        expect(eventData.newBlocksPerYear).toBe(modelParams.blocksPerYear);
        expect(eventData.newBaseRatePerBlock).toBe(modelParams.baseRatePerBlock);
        expect(eventData.newBaseMultiplierPerBlock).toBe(modelParams.baseMultiplierPerBlock);
        expect(eventData.newJumpMultiplierPerBlock).toBe(modelParams.jumpMultiplierPerBlock);
        expect(eventData.newCriticalUtilRate).toBe(modelParams.criticalUtilRate);
    });

    it("Update InterestRateModel params should match", async () => {
        await deployInterestRateModel();

        const admin = await getInterestRateModelAdmin();
        await shallPass(createInterestRateModel(
            admin,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            toUFix64(0.0),
            toUFix64(0.05),
            toUFix64(0.35),
            toUFix64(0.8)
        ));
        const oldParams = await getInterestRateModelParams();
        // Update model params
        const updateTxResult = await shallPass(updateInterestRateModelParams(
            admin,
            6666666,
            toUFix64(0.005),
            toUFix64(0.065),
            toUFix64(0.55),
            toUFix64(0.75)
        ));
        const updateEventData = updateTxResult.events[0].data;
        const newParams = await getInterestRateModelParams();

        expect(updateEventData.oldBlocksPerYear).toBe(oldParams.blocksPerYear);
        expect(updateEventData.newBlocksPerYear).toBe(newParams.blocksPerYear);
        expect(updateEventData.oldBaseRatePerBlock).toBe(oldParams.baseRatePerBlock);
        expect(updateEventData.newBaseRatePerBlock).toBe(newParams.baseRatePerBlock);
        expect(updateEventData.oldBaseMultiplierPerBlock).toBe(oldParams.baseMultiplierPerBlock);
        expect(updateEventData.newBaseMultiplierPerBlock).toBe(newParams.baseMultiplierPerBlock);
        expect(updateEventData.oldJumpMultiplierPerBlock).toBe(oldParams.jumpMultiplierPerBlock);
        expect(updateEventData.newJumpMultiplierPerBlock).toBe(newParams.jumpMultiplierPerBlock);
        expect(updateEventData.oldCriticalUtilRate).toBe(oldParams.criticalUtilRate);
        expect(updateEventData.newCriticalUtilRate).toBe(newParams.criticalUtilRate);
    });
})