import path from "path";
import { emulator, init, mintFlow, getAccountAddress, shallPass, shallRevert, getFlowBalance } from "flow-js-testing";
import { toUFix64, ScaleFactor } from "../setup/setup_common";
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

import {
    queryVaultBalance,
    queryPoolInfo,
    queryFlowTokenPoolState,
    queryCurrentBlockId,
    queryUserPoolState,
    nextBlock,

    supply,
    redeem
} from "../setup/setup_LendingPool";
import { hasUncaughtExceptionCaptureCallback } from "process";

const RandomEvnMaker = async() => {
    const user1 = await getAccountAddress("user_wqf")
    const user2 = await getAccountAddress("user_adi")
    await mintFlow(user1, "100.0")
    await mintFlow(user2, "1000.0")
    await supply(user1, 20.0)
    await supply(user2, 50.0)
}

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000)

describe("LendingPool Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence")
        // Note: Use different port for different testsuites to run test simultaneously. 
        const port = 7005
        await init(basePath, { port })
        await emulator.start(port, false)

        await preparePoolUnderlyingVault()
        await deployLendingPoolContract()
        await initInterestRateModel()
        await initOracle()
        await initComptroller()
        await initPool(0.01, 0.028)
        await addMarket(0.75, 10000.0, true, true)
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop()
    });
/*
    it("Supply: Local vault's balance should be withdrawn properly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        var totalAmount = toUFix64(100.0)
        const depositAmount = toUFix64(1.0)
        await mintFlow(userAddr1, totalAmount.toString())
        const preLocalBalance = await getFlowBalance(userAddr1)
        
        await shallPass(supply(userAddr1, depositAmount))
        await shallRevert(supply(userAddr1, totalAmount+0.00000001))
        
        const aftLocalBalance = await getFlowBalance(userAddr1)
        const delt = toUFix64(preLocalBalance - aftLocalBalance)
        // no gas cost
        expect(delt).toBe(depositAmount)
    });
    it("Supply (First Deposit) (Limit test 0.00000001): Pool's state shoule be changed rightly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        
        var totalAmount = toUFix64(100.0)
        const depositAmount = toUFix64(0.00000001)
        await mintFlow(userAddr1, totalAmount.toString())

        const prePoolInfo = await queryPoolInfo()
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preBlockID = await queryCurrentBlockId()

        await shallPass(supply(userAddr1, depositAmount))

        const aftPoolInfo = await queryPoolInfo()
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        const aftBlockID = await queryCurrentBlockId()
        
        const mintLpTokens = depositAmount * ScaleFactor / prePoolState.LpTokenMintRate * ScaleFactor
        
        // Pool's vault should deposit certain underlying tokens
        expect(aftPoolState.TotalCash - prePoolState.TotalCash).toBe( depositAmount * ScaleFactor )
        // LpToken should be minted rightly
        expect(aftPoolState.TotalSupply - prePoolState.TotalSupply).toBe( mintLpTokens )
        // The user's lptoken amount should be add rightly in ledger.
        expect(aftUserState[1] - preUserState[1]).toBe( mintLpTokens )
    });
    it("Supply (Limit test 9999): Pool's state shoule be changed rightly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        // randomly making test env
        await RandomEvnMaker()

        var totalAmount = toUFix64(1000000000.0)
        const depositAmount = toUFix64(999999999.99999999)
        await mintFlow(userAddr1, totalAmount.toString())

        const prePoolInfo = await queryPoolInfo()
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preBlockID = await queryCurrentBlockId()
        
        await shallPass(supply(userAddr1, depositAmount))
        
        const aftPoolInfo = await queryPoolInfo()
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        const aftBlockID = await queryCurrentBlockId()
        const mintLpTokens = depositAmount * ScaleFactor / prePoolState.LpTokenMintRate * ScaleFactor
        
        // Pool's vault should deposit certain underlying tokens
        expect(aftPoolState.TotalCash - prePoolState.TotalCash).toBe( depositAmount * ScaleFactor )
        // LpToken should be minted rightly
        expect(aftPoolState.TotalSupply - prePoolState.TotalSupply).toBe( mintLpTokens )
        // The user's lptoken amount should be add rightly in ledger.
        expect(aftUserState[1] - preUserState[1]).toBe( mintLpTokens )
    });
*/
    it("Redeem (Limit test 999): Pool's state shoule be changed rightly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        // randomly making test env
        await RandomEvnMaker()

        var totalAmount = toUFix64(1000000000.0)
        const depositAmount = toUFix64(999999999.99999999)
        const redeemAmount = toUFix64(999999999.99999999)
        await mintFlow(userAddr1, totalAmount.toString())
        await supply(userAddr1, depositAmount)

        const prePoolInfo = await queryPoolInfo()
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preBlockID = await queryCurrentBlockId()
        console.log(prePoolInfo)
        console.log(prePoolState)
        await shallPass(redeem(userAddr1, redeemAmount))
        
        const aftPoolInfo = await queryPoolInfo()
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        const aftBlockID = await queryCurrentBlockId()
        const mintLpTokens = redeemAmount * ScaleFactor / prePoolState.LpTokenMintRate * ScaleFactor
        console.log(aftPoolInfo)
        console.log(aftPoolState)
        console.log(999999999.99999999 * 1e18)
        console.log(mintLpTokens)
        // Pool's vault should deposit certain underlying tokens
        expect(prePoolState.TotalCash - aftPoolState.TotalCash).toBe( redeemAmount * ScaleFactor )
        // LpToken should be melt rightly
        expect(prePoolState.TotalSupply - aftPoolState.TotalSupply).toBe( mintLpTokens )
        // The user's lptoken amount should be sub rightly in ledger.
        expect(preUserState[1] - aftUserState[1]).toBe( mintLpTokens )
    });


/*
    it("Supply (First Deposit): Pool's state shoule be changed rightly.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        
        var totalAmount = toUFix64(100.0)
        const depositAmount = toUFix64(0.00000001)
        await mintFlow(userAddr1, totalAmount.toString())

        const prePoolInfo = await queryPoolInfo()
        const prePoolState = await queryFlowTokenPoolState()
        console.log(prePoolInfo)
        console.log(prePoolState)
        console.log("rate: "+(prePoolState.LpTokenMintRate/1e18))
        const preBlockID = await queryCurrentBlockId()
        const preTotalSupply = prePoolState.TotalSupply
        const preTotalCash = prePoolState.TotalCash
        const lpTokenMintRate = prePoolState.LpTokenMintRate
        

        await shallPass(supply(userAddr1, depositAmount))

        const aftPoolInfo = await queryPoolInfo()
        const aftPoolState = await queryFlowTokenPoolState()
        console.log(aftPoolInfo)
        console.log(aftPoolState)
        console.log("rate"+(prePoolState.LpTokenMintRate/1e18))
        const aftBlockID = await queryCurrentBlockId()
        const aftTotalSupply = prePoolState.TotalSupply
        const aftTotalCash = prePoolState.TotalCash

        // The interest rate should be updated
        expect(aftPoolState.BlockNumber).toBe(aftBlockID)
        // Pool's vault should deposit certain underlying tokens
        expect(aftPoolState.TotalCash - prePoolState.TotalCash).toBe( depositAmount * ScaleFactor )
        // LpToken should be minted rightly
        expect(aftPoolState.TotalSupply - prePoolState.TotalSupply).toBe( depositAmount * ScaleFactor * ScaleFactor / prePoolState.LpTokenMintRate )

        console.log(aftPoolState.TotalSupply - prePoolState.TotalSupply)
        console.log(depositAmount * ScaleFactor / prePoolState.LpTokenMintRate)
    });
*/
});