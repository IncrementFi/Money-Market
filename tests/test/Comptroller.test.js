import path from "path";
import BigNumber from "bignumber.js";
import { emulator, init, mintFlow, getAccountAddress, shallPass, shallRevert, getFlowBalance } from "flow-js-testing";
import { ScaleFactor, toUFix64 } from "../setup/setup_common";
import {
    deployLendingPoolContract,
    //
    preparePoolUnderlyingVault,
    initInterestRateModel,
    initOracle,
    initComptroller,
    initPool,
    addMarket,
    getLendingPoolAddress,
    updateOraclePrice,
} from "../setup/setup_Deployment";

import {
    queryFlowTokenPoolState,
    queryUserPoolState,
    queryFlowTokenInterestRate,
    nextBlock,

    supply,
    redeem,
    borrow,
    repay
} from "../setup/setup_LendingPool";

import {
    configMarket,
    queryUserLiquidity,
    queryUserAllPools
} from "../setup/setup_Comptroller";
import { exportAllDeclaration } from "@babel/types";


// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(600000)

describe("LendingPool Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence")
        // Note: Use different port for different testsuites to run test simultaneously. 
        const port = 7006
        await init(basePath, { port })
        await emulator.start(port, false)

        await preparePoolUnderlyingVault()
        await deployLendingPoolContract()
        await initInterestRateModel()
        await initOracle()
        await initComptroller()
        await initPool(toUFix64(0.01), toUFix64(0.028))
        await addMarket(toUFix64(0.05), toUFix64(0.8), toUFix64(100000000.0), true, true)
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop()
    });

    it("Close market test.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        await mintFlow(userAddr1, "100.0")
        
        await shallPass( supply( userAddr1, toUFix64(50) ) )
        await shallPass( borrow( userAddr1, toUFix64(20) ) )

        await configMarket(toUFix64(0.05), toUFix64(0.8), toUFix64(100000000.0), toUFix64(200000000.0), false, true)

        await shallRevert( supply( userAddr1, toUFix64(1) ) )
        await shallRevert( borrow( userAddr1, toUFix64(1) ) )
        await shallRevert( redeem( userAddr1, toUFix64(1) ) )
        await shallRevert( repay( userAddr1, toUFix64(1) ) )
    });

    it("Redeem allowed should check the user's liquidity and pool's collateral.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        await mintFlow(userAddr1, "100.0")

        await configMarket(toUFix64(0.05), toUFix64(0.8), toUFix64(100000000.0), toUFix64(200000000.0), true, true)

        await supply( userAddr1, toUFix64(100) )
        await borrow( userAddr1, toUFix64(20) )

        //const liquidity = await queryUserLiquidity(userAddr1)
        await shallRevert( redeem( userAddr1, toUFix64(75) ) )

        await shallPass( redeem( userAddr1, toUFix64(74) ) )
    });

    it("Borrow allowed should check the user's liquidity and pool's collateral.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        await mintFlow(userAddr1, "100.0")

        await configMarket(toUFix64(0.05), toUFix64(0.8), toUFix64(100000000.0), toUFix64(200000000.0), true, true)

        await supply( userAddr1, toUFix64(100) )
        await borrow( userAddr1, toUFix64(20) )
        
        await shallRevert( borrow( userAddr1, toUFix64(61) ) )

        await shallPass( borrow( userAddr1, toUFix64(59.99) ) )
    });

    it("User's market record should be removed correctly after redeeming all deposit.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        const poolAddr = await getLendingPoolAddress()
        await mintFlow(userAddr1, "100.0")

        await supply( userAddr1, toUFix64(100) )
        const prePools = await queryUserAllPools(userAddr1)

        await redeem( userAddr1, toUFix64(100) )
        const aftPools = await queryUserAllPools(userAddr1)
        
        expect(prePools).toContain(poolAddr)

        expect(aftPools).not.toContain(poolAddr)
    });
    
    it("The user's liquidty should be calculated correctly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        const poolAddr = await getLendingPoolAddress()
        await mintFlow(userAddr1, "100.0")

        await supply( userAddr1, toUFix64(100) )
        await borrow( userAddr1, toUFix64(50) )
        
        await updateOraclePrice(toUFix64(1.0))
        const liquidity = await queryUserLiquidity(userAddr1)

        // collateral value
        expect(
            BigNumber(liquidity[0]).toFixed(8)
        ).toBe(
            BigNumber("80").times(ScaleFactor).toFixed(8)
        )
        // borrow value
        expect(
            BigNumber(liquidity[1]).toFixed(8)
        ).toBe(
            BigNumber("50").times(ScaleFactor).toFixed(8)
        )
    });

    it("Market's borrow cap test.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        const poolAddr = await getLendingPoolAddress()
        await mintFlow(userAddr1, "100.0")

        await supply( userAddr1, toUFix64(100) )

        await configMarket(toUFix64(0.05), toUFix64(0.8), toUFix64(10.0), toUFix64(200000000.0), true, true)

        await shallRevert( borrow( userAddr1, toUFix64(11) ) )
        await shallPass( borrow( userAddr1, toUFix64(10) ) )
    });

    it("Market's supply cap test.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        const poolAddr = await getLendingPoolAddress()
        await mintFlow(userAddr1, "100.0")

        await supply( userAddr1, toUFix64(100) )

        await configMarket(toUFix64(0.05), toUFix64(0.8), toUFix64(10.0), toUFix64(20.0), true, true)

        await shallRevert( supply( userAddr1, toUFix64(21) ) )
        await shallPass( supply( userAddr1, toUFix64(19) ) )
    });
});