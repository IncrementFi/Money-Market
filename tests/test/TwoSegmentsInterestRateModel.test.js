import path from "path";
import { emulator, init, getAccountAddress, shallPass } from "flow-js-testing";
import { toUFix64 } from "../setup/setup_common";
import {
    deployInterestRateModel,
    createInterestRateModel,
    updateInterestRateModelParams,
    getInterestRateModelParams,
} from "../setup/setup_TwoSegmentsInterestRateModel";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(10000);

describe("InterestRateModel Testsuites", () => {
    beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../../cadence");
		const port = 7001;
		await init(basePath, { port });
		return emulator.start(port, false);
	});
    // Stop emulator, so it could be restarted
	afterEach(async () => {
		return emulator.stop();
	});

    it("deploy InterestRateModel", async () => {
        await shallPass(deployInterestRateModel());
    });
})