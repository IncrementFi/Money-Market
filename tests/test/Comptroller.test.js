import path from "path";
import BigNumber from "bignumber.js";
import { emulator, init, mintFlow, getAccountAddress, shallPass, shallRevert, getFlowBalance } from "flow-js-testing";
import { ScaleFactor } from "../setup/setup_common";
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
jest.setTimeout(100000)

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
        await initPool(0.01, 0.028)
        await addMarket(0.8, 100000000.0, true, true)
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop()
    });

    it("Close market test.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        await mintFlow(userAddr1, "100.0")
        
        await shallPass( supply( userAddr1, "50" ) )
        await shallPass( borrow( userAddr1, "20" ) )

        await configMarket(0.8, 100000000.0, false, true)

        await shallRevert( supply( userAddr1, "1" ) )
        await shallRevert( borrow( userAddr1, "1" ) )
        await shallRevert( redeem( userAddr1, "1" ) )
        await shallRevert( repay( userAddr1, "1" ) )
    });

    it("Redeem allowed should check the user's liquidity and pool's collateral.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        await mintFlow(userAddr1, "100.0")

        await configMarket(0.8, 100000000.0, true, true)

        await supply( userAddr1, "100" )
        await borrow( userAddr1, "20" )

        //const liquidity = await queryUserLiquidity(userAddr1)
        await shallRevert( redeem( userAddr1, "75" ) )

        await shallPass( redeem( userAddr1, "74" ) )
    });

    it("Borrow allowed should check the user's liquidity and pool's collateral.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        await mintFlow(userAddr1, "100.0")

        await configMarket(0.8, 100000000.0, true, true)

        await supply( userAddr1, "100" )
        await borrow( userAddr1, "20" )
        
        await shallRevert( borrow( userAddr1, "61" ) )

        await shallPass( borrow( userAddr1, "59.99" ) )
    });

    it("User's market record should be removed correctly after redeeming all deposit.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        const poolAddr = await getLendingPoolAddress()
        await mintFlow(userAddr1, "100.0")

        await supply( userAddr1, "100" )
        const prePools = await queryUserAllPools(userAddr1)

        await redeem( userAddr1, "100" )
        const aftPools = await queryUserAllPools(userAddr1)
        
        expect(prePools).toContain(poolAddr)

        expect(aftPools).not.toContain(poolAddr)
    });
    
    it("The user's liquidty should be calculated correctly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        const poolAddr = await getLendingPoolAddress()
        await mintFlow(userAddr1, "100.0")

        await supply( userAddr1, "100" )
        await borrow( userAddr1, "50" )
        
        await updateOraclePrice(1.0)
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

        await supply( userAddr1, "100" )

        await configMarket(0.8, 10.0, true, true)

        await shallRevert( borrow( userAddr1, "11" ) )
        await shallPass( borrow( userAddr1, "10" ) )
    });
});