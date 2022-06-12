import path from "path";
import { emulator, init, getAccountAddress, shallPass, shallRevert } from "flow-js-testing";
import { toUFix64 } from "../setup/setup_common";
import {
    getOracleContractAddress,
    deploySimpleOracleContract,
    createOracleResource,
    adminAddPriceFeed,
    adminRemovePriceFeed,
    adminGrantUpdateRole,
    adminRevokeUpdateRole,
    getSupportedDataFeeds,
    getFeedLatestResult,
    checkUpdaterSetupStatus,
    updaterSetupAccount,
    updaterUpdateData,
} from "../setup/setup_SimpleOracle";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000);

describe("SimpleOracle Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence");
        // Note: Use different port for different testsuites to run test simultaneously. 
        const port = 7002;
        await init(basePath, { port });
        return emulator.start(port, false);
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop();
    });

    it("Should deploy contract and create Oracle resource successfully", async () => {
        await shallPass(deploySimpleOracleContract());
        await shallPass(createOracleResource());
    });

    it("Should config price feeds successfully", async () => {
        await deploySimpleOracleContract();
        await createOracleResource();

        // test initial status
        const oracleAddress = await getOracleContractAddress();
        let [feeds] = await getSupportedDataFeeds(oracleAddress);
        expect(feeds.length).toBe(0);

        // test add price feed
        const testYToken1 = await getAccountAddress("pool1");
        await shallPass(adminAddPriceFeed(testYToken1, 100));
        [feeds] = await getSupportedDataFeeds(oracleAddress);
        expect(feeds.length).toBe(1);
        expect(feeds).toContain(testYToken1);

        // test add duplicate feeds no duplicate result
        await shallPass(adminAddPriceFeed(testYToken1, 100));
        [feeds] = await getSupportedDataFeeds(oracleAddress);
        expect(feeds.length).toBe(1);
        expect(feeds).toContain(testYToken1);

        // test add multiple feeds
        const testYToken2 = await getAccountAddress("pool2");
        await shallPass(adminAddPriceFeed(testYToken2, 50));
        [feeds] = await getSupportedDataFeeds(oracleAddress);
        expect(feeds.length).toBe(2);
        expect(feeds).toContain(testYToken1);
        expect(feeds).toContain(testYToken2);

        // test Remove price feed
        await shallPass(adminRemovePriceFeed(testYToken2));
        [feeds] = await getSupportedDataFeeds(oracleAddress);
        expect(feeds.length).toBe(1);
        expect(feeds).toContain(testYToken1);
        expect(feeds).not.toContain(testYToken2);
    });

    it("Updater provisions account with admin successfully grant & revoke its updateCapability", async () => {
        await deploySimpleOracleContract();
        await createOracleResource();

        // Check initial setup status
        const updater = await getAccountAddress("feed-updater");
        let [setupResult] = await checkUpdaterSetupStatus(updater);
        expect(setupResult).toBe(false);

        // Setup updater account, the status should still be false as it's not yet granted with updateCapability.
        await shallPass(updaterSetupAccount(updater));
        [setupResult] = await checkUpdaterSetupStatus(updater);
        expect(setupResult).toBe(false);

        // Admin grant updateCapability to updater and now it's been setup.
        await shallPass(adminGrantUpdateRole(updater));
        [setupResult] = await checkUpdaterSetupStatus(updater);
        expect(setupResult).toBe(true);

        // Admin revoke updateCapability then check updater status.
        await shallPass(adminRevokeUpdateRole());
        [setupResult] = await checkUpdaterSetupStatus(updater);
        expect(setupResult).toBe(false);

        // Let's grant and check once again.
        await shallPass(adminGrantUpdateRole(updater));
        [setupResult] = await checkUpdaterSetupStatus(updater);
        expect(setupResult).toBe(true);
    });

    it("Updater uploads data to specified feed and read feed's latest result should match", async () => {
        await deploySimpleOracleContract();
        await createOracleResource();

        // UpdaterCapability grant
        const updater = await getAccountAddress("feed-updater");
        await shallPass(updaterSetupAccount(updater));
        await shallPass(adminGrantUpdateRole(updater));

        const oracleAddress = await getOracleContractAddress();
        // Add price feed
        const testYToken1 = await getAccountAddress("pool1");
        await shallPass(adminAddPriceFeed(testYToken1, 3));
        // Upload 4 data points, which should wrap in the RingBuffer (capacity 3), and check every latest result.
        const data = [toUFix64(35.5), toUFix64(36.6), toUFix64(37.7), toUFix64(38.8)];
        for (let i = 0; i < data.length; i++) {
            await shallPass(updaterUpdateData(updater, testYToken1, data[i]));
            let [res] = await getFeedLatestResult(oracleAddress, testYToken1);
            expect(res[1]).toBe(data[i]);
        }
    });
});
