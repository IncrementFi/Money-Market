import path from "path";
import BigNumber from "bignumber.js";
import { emulator, init, mintFlow, getAccountAddress, shallPass, shallRevert, getFlowBalance } from "flow-js-testing";
import { ScaleFactor, toUFix64 } from "../setup/setup_common";
import {
    deployLendingPoolContract,
    getLendingPoolAddress,
    //
    preparePoolUnderlyingVault,
    initInterestRateModel,
    initOracle,
    initComptroller,
    initPool,
    addMarket,
} from "../setup/setup_Deployment";

import {
    queryFlowTokenPoolState,
    queryUserPosition,
    queryUserPoolState,
    queryFlowTokenInterestRate,
    nextBlock,

    supply,
    redeem,
    borrow,
    repay,
    liquidate,
} from "../setup/setup_LendingPool";
import { hasUncaughtExceptionCaptureCallback } from "process";


/**
 * Emulate the calculation of AccrueInterest
 * @returns Accrue results of TotalBorrows, TotalReserves {BigNumber}
 */
 function CalculateAccrueInterest(prePoolState, nextBlockNumber, preInterestState) {
    const deltInterestRate = BigNumber(preInterestState[1]).times(nextBlockNumber-prePoolState.BlockNumber)
    const deltInterest = BigNumber(prePoolState.TotalBorrows).times(deltInterestRate).dividedBy(BigNumber(ScaleFactor))
    const newBorrow = BigNumber(prePoolState.TotalBorrows).plus(deltInterest)
    const newReserve = BigNumber(prePoolState.TotalReserves).plus(
        deltInterest.times(BigNumber(prePoolState.ReserveFactor)).dividedBy(BigNumber(ScaleFactor))
    )
    return {
        "TotalBorrows": newBorrow,
        "TotalReserves": newReserve
    }
}

/**
 * Emulate the calculation of Token mint rate
 * @params {BigNumber}
 * @returns Accrue results of TotalBorrows, TotalReserves (BigNumber type)
 */
function CalculateLpTokenMintRate(totalCash, totalBorrow, totalReserve, totalSupply) {
    return (BigNumber(totalCash).plus(totalBorrow).minus(totalReserve))
                                .times(BigNumber(1e18)).dividedBy(BigNumber(totalSupply))
                                .integerValue(BigNumber.ROUND_FLOOR)
}

const RandomEvnMaker = async() => {
    const user1 = await getAccountAddress("user_wqf")
    const user2 = await getAccountAddress("user_adi")
    await mintFlow(user1, "100.0")
    await mintFlow(user2, "1000.0")
    await supply(user1, toUFix64(20.0))
    await supply(user2, toUFix64(50.0))
    await redeem(user2, toUFix64(1.0))
    await borrow(user2, toUFix64(1.0))
    await repay(user2, toUFix64(1.0))
    await borrow(user1, toUFix64(10.0))
}


// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000)
const collateralRate = 0.8
const liquidatePenalty = 0.05
const seizeFactor = 0.028

describe("LendingPool Testsuites", () => {
    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../cadence")
        // Note: Use different port for different testsuites to run test simultaneously. 
        const port = 7007
        await init(basePath, { port })
        await emulator.start(port, false)

        await preparePoolUnderlyingVault()
        await deployLendingPoolContract()
        await initInterestRateModel()
        await initOracle()
        await initComptroller()
        await initPool(toUFix64(0.01), toUFix64(seizeFactor))
        await addMarket(toUFix64(liquidatePenalty), toUFix64(collateralRate), toUFix64(100000000.0), true, true)
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop()
    });

    it("Liquidation test", async () => {
        BigNumber.config({ DECIMAL_PLACES: 8 })

        const liquidatorInitVaultBalance = BigNumber("100.0")
        const borrowerInitVaultBalance = BigNumber("100.0")
        const liquidator = await getAccountAddress("liquidator")
        const borrower = await getAccountAddress("borrower")
        // mint flow token
        await mintFlow(liquidator, liquidatorInitVaultBalance.toFixed(8))
        await mintFlow(borrower, borrowerInitVaultBalance.toFixed(8))

        await supply(borrower, borrowerInitVaultBalance.toFixed(8))
        await borrow(borrower, borrowerInitVaultBalance.times(collateralRate).toFixed(8))

        await nextBlock()

        const prePoolState = await queryFlowTokenPoolState()
        const preBorrowerState = await queryUserPoolState(borrower)
        console.log(prePoolState)
        console.log(preBorrowerState)


        const seizePoolAddr = await getLendingPoolAddress()
        const curBorrowBalance = BigNumber(prePoolState['TotalBorrows'])
        const liquidateAmount = curBorrowBalance.times(0.5).dividedBy(1e18)
        const liquidateAmountError = liquidateAmount.plus(BigNumber(0.001))
        const preInterestState = await queryFlowTokenInterestRate(
            BigNumber(prePoolState.TotalCash).toNumber(),
            BigNumber(prePoolState.TotalBorrows).toNumber(),
            BigNumber(prePoolState.TotalReserves).toNumber()
        )
        // liquidate
        //await shallRevert( liquidate(liquidator, borrower, seizePoolAddr, liquidateAmountError.toFixed(8)) )
        await shallPass( liquidate(liquidator, borrower, seizePoolAddr, liquidateAmount.toFixed(8)) )

        const aftPoolState = await queryFlowTokenPoolState()
        const aftBorrowerState = await queryUserPoolState(borrower)
        const aftLiuidatorState = await queryUserPoolState(liquidator)
        
        console.log(aftPoolState)
        console.log(aftBorrowerState)
        console.log(aftLiuidatorState)
        
        const curBorrowIndex = BigNumber(aftPoolState.BorrowIndex)
        const preBorrowPrincipal = BigNumber(preBorrowerState[3])
        const preBorrowIndex = BigNumber(preBorrowerState[4])
        const curBorrow = preBorrowPrincipal.times(curBorrowIndex).dividedBy(preBorrowIndex).integerValue(BigNumber.ROUND_FLOOR)
        const deltInterest = BigNumber(preInterestState[1]).times( aftPoolState.BlockNumber-prePoolState.BlockNumber )
        // the borrower's debt should be repayed correctly
        console.log(deltInterest.toFixed(16))
        expect(
            (curBorrow.dividedBy(1e18) - liquidateAmount).toFixed(8)
        ).toBe(
            BigNumber(aftBorrowerState[2]).dividedBy(1e18).toFixed(8)
        )
        
        // the panelty should be correctly saved into reserve
        expect(
            BigNumber(aftPoolState.TotalReserves).minus(BigNumber(prePoolState.TotalReserves)).dividedBy(1e10).integerValue(BigNumber.ROUND_FLOOR).toFixed(8)
        ).toBe(
            liquidateAmount.times(1e18).times(BigNumber(1.0+liquidatePenalty)).times(seizeFactor)
            .plus(deltInterest.times(BigNumber(prePoolState.TotalBorrows)).dividedBy(1e18).times(0.01)).dividedBy(1e10)
            .integerValue(BigNumber.ROUND_FLOOR).toFixed(8)
        )
    });

});