import path from "path";
import { emulator, init, getAccountAddress, shallPass, shallRevert } from "flow-js-testing";
import { toUFix64 } from "../setup/setup_common";
import {
    getInterestRateModelAdmin,
    deployInterestRateModel,
    createInterestRateModel,
    updateInterestRateModelParams,
    getInterestRateModelParams,
    getInterestRateData,
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
        const scaleFactor = 1e18;
        await shallRevert(createInterestRateModel(
            alice,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            0,
            5 * scaleFactor / 100,   // 0.05
            35 * scaleFactor / 100,  // 0.35
            80 * scaleFactor / 100   // 0.8
        ));
    });

    it("Create InterestRateModel Resource then check model params should match", async () => {
        await deployInterestRateModel();

        const admin = await getInterestRateModelAdmin();
        const scaleFactor = 1e18;
        const createTxResult = await shallPass(createInterestRateModel(
            admin,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            0,
            5 * scaleFactor / 100,   // 0.05
            35 * scaleFactor / 100,  // 0.35
            80 * scaleFactor / 100   // 0.8
        ));
        const modelParams = await getInterestRateModelParams();
        const eventData = createTxResult.events[0].data;
        expect(eventData.newBlocksPerYear).toBe(modelParams.blocksPerYear);
        expect(eventData.newScaledBaseRatePerBlock).toBe(modelParams.scaledBaseRatePerBlock);
        expect(eventData.newScaledBaseMultiplierPerBlock).toBe(modelParams.scaledBaseMultiplierPerBlock);
        // Manual calculation and do the comparison to double check. Should be '4954654997'
        let calculateScaledBaseMultiplierPerBlock = Math.trunc(0.05 / 0.8 * scaleFactor / 12614400)
        expect(eventData.newScaledBaseMultiplierPerBlock).toBe(calculateScaledBaseMultiplierPerBlock)
        expect(eventData.newScaledJumpMultiplierPerBlock).toBe(modelParams.scaledJumpMultiplierPerBlock);
        expect(eventData.newScaledCriticalUtilRate).toBe(modelParams.scaledCriticalUtilRate);
    });

    it("Create InterestRateModel Resource then check interest rates", async () => {
        await deployInterestRateModel();

        const admin = await getInterestRateModelAdmin();
        const scaleFactor = 1e18;
        await shallPass(createInterestRateModel(
            admin,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            0,
            5 * scaleFactor / 100,  // 0.05
            35 * scaleFactor / 100, // 0.35
            80 * scaleFactor / 100  // 0.8
        ));     
        const interestRates = await getInterestRateData(
            100 * scaleFactor,
            400 * scaleFactor,
            0
        );
        let utilRate = interestRates[0]
        let borrowRate = interestRates[1]
        let supplyRate = interestRates[2]
        // According to the interest rate model, annual Borrow Rate should be 5% when capital utilization rate is 80%
        expect(borrowRate * 12614400 / scaleFactor).toBeCloseTo(0.05)
    });

    it("Update InterestRateModel params should match", async () => {
        await deployInterestRateModel();

        const admin = await getInterestRateModelAdmin();
        const scaleFactor = 1e18;
        await shallPass(createInterestRateModel(
            admin,
            "TwoSegmentsInterestRateModelV1-test",
            12614400,
            0,
            5 * scaleFactor / 100,   // 0.05
            35 * scaleFactor / 100,  // 0.35
            80 * scaleFactor / 100   // 0.8
        ));
        const oldParams = await getInterestRateModelParams();
        // Update model params
        const updateTxResult = await shallPass(updateInterestRateModelParams(
            admin,
            31536000,
            0.5 * scaleFactor / 100,  // 0.005
            6.5 * scaleFactor / 100,  // 0.065
            55 * scaleFactor / 100,   // 0.55
            75 * scaleFactor / 100    // 0.75
        ));
        const updateEventData = updateTxResult.events[0].data;
        const newParams = await getInterestRateModelParams();
        // Manual calculation and do the comparison to double check. Should be '2536783358'
        let calculateScaledBaseMultiplierPerBlock = Math.trunc((0.065 - 0.005) / 0.75 * 1e18 / 31536000)
        expect(updateEventData.newScaledBaseMultiplierPerBlock).toBe(calculateScaledBaseMultiplierPerBlock)

        expect(updateEventData.oldBlocksPerYear).toBe(oldParams.blocksPerYear);
        expect(updateEventData.newBlocksPerYear).toBe(newParams.blocksPerYear);
        expect(updateEventData.oldScaledBaseRatePerBlock).toBe(oldParams.scaledBaseRatePerBlock);
        expect(updateEventData.newScaledBaseRatePerBlock).toBe(newParams.scaledBaseRatePerBlock);
        expect(updateEventData.oldScaledBaseMultiplierPerBlock).toBe(oldParams.scaledBaseMultiplierPerBlock);
        expect(updateEventData.newScaledBaseMultiplierPerBlock).toBe(newParams.scaledBaseMultiplierPerBlock);
        expect(updateEventData.oldScaledJumpMultiplierPerBlock).toBe(oldParams.scaledJumpMultiplierPerBlock);
        expect(updateEventData.newScaledJumpMultiplierPerBlock).toBe(newParams.scaledJumpMultiplierPerBlock);
        expect(updateEventData.oldScaledCriticalUtilRate).toBe(oldParams.scaledCriticalUtilRate);
        expect(updateEventData.newScaledCriticalUtilRate).toBe(newParams.scaledCriticalUtilRate);
    });
})
