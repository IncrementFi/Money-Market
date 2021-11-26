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
    await supply(user1, 20.0)
    await supply(user2, 50.0)
    await redeem(user2, 1.0)
    await borrow(user2, 1.0)
    await repay(user2, 1.0)
    await borrow(user1, 10.0)
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
        await addMarket(0.8, 100000000.0, true, true)
    });
    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop()
    });

    it("Supply (First Deposit) (Bottom Limit test): Pool&User's data state shoule be changed correctly.", async () => {
        // randomly making test env
        await RandomEvnMaker()
        
        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount =   BigNumber("0.00000001")
        const depositAmount = BigNumber("0.00000001")
        await mintFlow(userAddr1, totalAmount.toFixed(8))

        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        
        // supply
        await shallPass( supply( userAddr1, depositAmount.toFixed(8) ) )
        await shallRevert( supply( userAddr1, totalAmount.plus(0.00000001).toFixed(8) ) )

        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        
        const mintRate = CalculateLpTokenMintRate(
            BigNumber(prePoolState.TotalCash),
            BigNumber(aftPoolState.TotalBorrows),  // accrued
            BigNumber(aftPoolState.TotalReserves),
            BigNumber(prePoolState.TotalSupply)
        )
        const mintLpTokens = depositAmount.times(BigNumber(ScaleFactor)).times(BigNumber(ScaleFactor))
                                          .dividedBy(mintRate).integerValue(BigNumber.ROUND_FLOOR)
        
        // Pool's vault should deposit certain underlying tokens
        expect(
            BigNumber(aftPoolState.TotalCash).minus(BigNumber(prePoolState.TotalCash)).toFixed(8)
        ).toBe(
            depositAmount.times(ScaleFactor).toFixed(8)
        )
        // LpToken should be minted rightly
        expect(
            BigNumber(aftPoolState.TotalSupply).minus(BigNumber(prePoolState.TotalSupply)).toFixed(8)
        ).toBe(
            mintLpTokens.toFixed(8)
        )
        // The user's lptoken amount should be added rightly in ledger.
        expect(
            BigNumber(aftUserState[1]).minus(BigNumber(preUserState[1])).toFixed(8)
        ).toBe(
            mintLpTokens.toFixed(8)
        )
        // User's local vault should be modified correctly.
        expect(
            BigNumber(preLocalBalance).minus(BigNumber(aftLocalBalance)).toFixed(8)
        ).toBe(
            depositAmount.toFixed(8)
        )
    });

    it("Supply (Up Limit Test): Pool&User's data state shoule be changed rightly.", async () => {
        // randomly making test env
        await RandomEvnMaker()
        
        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount =   BigNumber("100000000.0")
        const depositAmount = BigNumber("99999999.99999999")
        await mintFlow(userAddr1, totalAmount.toFixed(8))

        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        
        // supply
        await shallPass( supply( userAddr1, depositAmount.toFixed(8) ) )

        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)

        const mintRate = CalculateLpTokenMintRate(
            BigNumber(prePoolState.TotalCash),
            BigNumber(aftPoolState.TotalBorrows),  // accrued
            BigNumber(aftPoolState.TotalReserves),
            BigNumber(prePoolState.TotalSupply)
        )
        const mintLpTokens = depositAmount.times(BigNumber(ScaleFactor)).times(BigNumber(ScaleFactor))
                                          .dividedBy(mintRate).integerValue(BigNumber.ROUND_FLOOR)
        
        // Pool's vault should deposit certain underlying tokens
        expect(
            BigNumber(aftPoolState.TotalCash).minus(BigNumber(prePoolState.TotalCash)).toFixed(8)
        ).toBe(
            depositAmount.times(ScaleFactor).toFixed(8)
        )
        // LpToken should be minted rightly
        expect(
            BigNumber(aftPoolState.TotalSupply).minus(BigNumber(prePoolState.TotalSupply)).toFixed(8)
        ).toBe(
            mintLpTokens.toFixed(8)
        )
        // The user's lptoken amount should be added rightly in ledger.
        expect(
            BigNumber(aftUserState[1]).minus(BigNumber(preUserState[1])).toFixed(8)
        ).toBe(
            mintLpTokens.toFixed(8)
        )
        // User's local vault should be modified correctly.
        expect(
            BigNumber(preLocalBalance).minus(BigNumber(aftLocalBalance)).toFixed(8)
        ).toBe(
            depositAmount.toFixed(8)
        )
    });

    // Max UFix64 doesn't work on jest. Test Pending.
    it("Redeem (Up Limit Test): Max redeem test.", async () => {
    });

    it("Redeem (Up Limit Test): Basic logic without interestRate & borrow.", async () => {
        // randomly making test env
        await RandomEvnMaker()

        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount = BigNumber("100000000.0")
        const depositAmount = BigNumber("99999999.99999999")
        const redeemAmount = BigNumber("99999999.99999999")
        await mintFlow( userAddr1, totalAmount.toFixed(8) )
        await supply( userAddr1, depositAmount.toFixed(8) )

        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)

        // redeem
        await shallRevert( redeem( userAddr1, depositAmount.plus(0.00000001).toFixed(8) ) )
        await shallPass( redeem( userAddr1, redeemAmount.toFixed(8) ) )
        
        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)

        const mintRate = CalculateLpTokenMintRate(
            BigNumber(prePoolState.TotalCash),
            BigNumber(aftPoolState.TotalBorrows),  // accrued
            BigNumber(aftPoolState.TotalReserves),
            BigNumber(prePoolState.TotalSupply)
        )
        const meltLpTokens = redeemAmount.times(BigNumber(ScaleFactor)).times(BigNumber(ScaleFactor))
                                          .dividedBy(mintRate).integerValue(BigNumber.ROUND_FLOOR)

        // Pool's vault should withdraw certain underlying tokens
        expect(
            BigNumber(prePoolState.TotalCash).minus( BigNumber(aftPoolState.TotalCash) ).toFixed(8)
        ).toBe(
            redeemAmount.times(ScaleFactor).toFixed(8)
        )
        // LpToken should be melt rightly
        expect(
            BigNumber(prePoolState.TotalSupply).minus( BigNumber(aftPoolState.TotalSupply) ).toFixed(8)
        ).toBe(
            meltLpTokens.toFixed(8)
        )
        // The user's lptoken amount should be decreased rightly in ledger.
        expect(
            BigNumber(preUserState[1]).minus( BigNumber(aftUserState[1]) ).toFixed(8)
        ).toBe(
            meltLpTokens.toFixed(8)
        )
        // User's local vault should be modified correctly.
        expect(
            BigNumber(aftLocalBalance).minus( BigNumber(preLocalBalance) ).toFixed(8)
        ).toBe(
            redeemAmount.toFixed(8)
        )
    });

    it("Borrow: Basic logic test", async () => {
        await RandomEvnMaker()

        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount = BigNumber("100.0")
        const depositAmount = BigNumber("100.0")
        const borrowAmount = BigNumber("50.0")
        const borrowAmountScaled = borrowAmount.times(ScaleFactor)
        await mintFlow( userAddr1, totalAmount.toFixed(8) )
        await supply( userAddr1, depositAmount.toFixed(8) )
        await borrow( userAddr1, "1.0" )
        await nextBlock()

        
        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preInterestState = await queryFlowTokenInterestRate(
            BigNumber(prePoolState.TotalCash).toNumber(),
            BigNumber(prePoolState.TotalBorrows).toNumber(),
            BigNumber(prePoolState.TotalReserves).toNumber()
        )
        
        // borrow
        await shallPass( borrow( userAddr1, borrowAmount.toFixed(8) ) )
        
        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        
        // Pool's vault should withdraw certain underlying tokens when borrowing
        expect(
            BigNumber(prePoolState.TotalCash).minus( BigNumber(aftPoolState.TotalCash) ).toFixed(8)
        ).toBe(
            borrowAmountScaled.toFixed(8)
        )
        // Total LpToken should be the same
        expect(
            BigNumber(prePoolState.TotalSupply).toFixed(8)
        ).toBe(
            BigNumber(aftPoolState.TotalSupply).toFixed(8)
        )
        // User's local vault should be added correctly.
        expect(
            BigNumber(aftLocalBalance).minus( BigNumber(preLocalBalance) ).toFixed(8)
        ).toBe(
            borrowAmount.toFixed(8)
        )

        const curBorrowIndex = BigNumber(aftPoolState.BorrowIndex)
        const preBorrowPrincipal = BigNumber(preUserState[3])
        const preBorrowIndex = BigNumber(preUserState[4])
        const curBorrow = preBorrowPrincipal.times(curBorrowIndex).dividedBy(preBorrowIndex).integerValue(BigNumber.ROUND_FLOOR)
        // The user's borrow snapshot should be updated correctly.
        expect(
            BigNumber(curBorrow).plus(borrowAmountScaled).toFixed(8)
        ).toBe(
            BigNumber(aftUserState[3]).toFixed(8)
        )
        const deltInterest = BigNumber(preInterestState[1]).times( aftPoolState.BlockNumber-prePoolState.BlockNumber )
        // Total borrow should be added correctly.
        expect(
            BigNumber(prePoolState.TotalBorrows)
                .times(deltInterest).dividedBy(BigNumber(ScaleFactor)).plus(BigNumber(prePoolState.TotalBorrows))
                .plus(borrowAmountScaled)
                .integerValue(BigNumber.ROUND_FLOOR).toFixed(8)
        ).toBe(
            BigNumber(aftPoolState.TotalBorrows).toFixed(8)
        )
    });

    it("Repay: (repayAmount < depositAmount) One Borrower test, the total_borrow should match the single user's borrow amount.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount =   BigNumber("200000.0")
        const depositAmount = BigNumber("200000.0")
        const borrowAmount =  BigNumber("100000.0")
        const repayAmount =   BigNumber("100000.0")
        const repayAmountScaled = repayAmount.times(BigNumber(ScaleFactor))

        await mintFlow( userAddr1, totalAmount.toFixed(8) )
        await supply( userAddr1, depositAmount.toFixed(8) )
        await borrow( userAddr1, borrowAmount.toFixed(8) )
        
        await nextBlock()
        await nextBlock()
        
        
        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preInterestState = await queryFlowTokenInterestRate()
        
        // repay
        await shallPass( repay( userAddr1, repayAmount.toFixed(8) ) )
        
        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        
        // Under one borrower, the totalBorrow should close to the user's borrow snapshot if borrowIndex is up-to-date.
        // Be tolarent of the loss of precision
        if(aftUserState[4] == aftPoolState.BorrowIndex) {
            expect(
                BigNumber(aftPoolState.TotalBorrows).dividedBy(1e10).toNumber()
            ).toBeCloseTo(
                BigNumber(aftUserState[2]).dividedBy(1e10).toNumber(),
                4
            )
        }
        
        // Pool's vault should deposited certain underlying tokens when repaying
        expect(
            BigNumber(aftPoolState.TotalCash).minus( BigNumber(prePoolState.TotalCash) ).toFixed(8)
        ).toBe(
            repayAmountScaled.toFixed(8)
        )
        // User's local vault change.
        expect(
            BigNumber(preLocalBalance).minus( BigNumber(aftLocalBalance) ).toFixed(8)
        ).toBe(
            repayAmount.toFixed(8)
        )

        const curBorrowIndex = BigNumber(aftPoolState.BorrowIndex)
        const preBorrowPrincipal = BigNumber(preUserState[3])
        const preBorrowIndex = BigNumber(preUserState[4])
        const curBorrow = preBorrowPrincipal.times(curBorrowIndex).dividedBy(preBorrowIndex).integerValue(BigNumber.ROUND_FLOOR)
        // The user's borrow snapshot should be updated correctly.
        expect(
            BigNumber(curBorrow).minus(repayAmountScaled).toFixed(8)
        ).toBe(
            BigNumber(aftUserState[3]).toFixed(8)
        )
        const deltInterest = BigNumber(preInterestState[1]).times( aftPoolState.BlockNumber-prePoolState.BlockNumber )
        // Total borrow should be decreased correctly.
        expect(
            BigNumber(prePoolState.TotalBorrows)
                .times(deltInterest).dividedBy(BigNumber(ScaleFactor)).plus(BigNumber(prePoolState.TotalBorrows))
                .minus(repayAmountScaled)
                .integerValue(BigNumber.ROUND_FLOOR).toFixed(8)
        ).toBe(
            BigNumber(aftPoolState.TotalBorrows).toFixed(8)
        )
    });

    it("Repay: (repayAmount > depositAmount) The excess repay amount should be returned to local user's vault.", async () => {
        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount =   BigNumber("200000.0")
        const depositAmount = BigNumber("100000.0")
        const borrowAmount =  BigNumber("50000.0")
        const repayAmount =   BigNumber("100000.0")

        await mintFlow( userAddr1, totalAmount.toFixed(8) )
        await supply( userAddr1, depositAmount.toFixed(8) )
        await borrow( userAddr1, borrowAmount.toFixed(8) )
        
        await nextBlock()
        await nextBlock()
        
        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preInterestState = await queryFlowTokenInterestRate()
        // repay
        await shallPass( repay( userAddr1, repayAmount.toFixed(8) ) )
        
        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)
        
        const curBorrowIndex = BigNumber(aftPoolState.BorrowIndex)
        const preBorrowPrincipal = BigNumber(preUserState[3])
        const preBorrowIndex = BigNumber(preUserState[4])
        const curBorrow = preBorrowPrincipal.times(curBorrowIndex).dividedBy(preBorrowIndex).integerValue(BigNumber.ROUND_FLOOR)
        
        // Convert to UFix64.8 precision and add 0.00000001 for clearing borrow amount.
        const actualRepayAmount = curBorrow.times(1e8).dividedBy(BigNumber(1e18)).integerValue(BigNumber.ROUND_FLOOR)
            .plus(BigNumber(1.0)).times(1e10)

        // Under one borrower, the totalBorrow should close to the user's borrow snapshot if borrowIndex is up-to-date.
        // Be tolarent of the loss of precision
        if(aftUserState[4] == aftPoolState.BorrowIndex) {
            expect(
                BigNumber(aftPoolState.TotalBorrows).dividedBy(1e10).toNumber()
            ).toBeCloseTo(
                BigNumber(aftUserState[2]).dividedBy(1e10).toNumber(),
                4
            )
        }
        
        // Pool's vault should deposited certain underlying tokens when repaying
        expect(
            BigNumber(aftPoolState.TotalCash).minus( BigNumber(prePoolState.TotalCash) ).toFixed(8)
        ).toBe(
            actualRepayAmount.toFixed(8)
        )
        // User's local vault change.
        expect(
            BigNumber(preLocalBalance).minus( BigNumber(aftLocalBalance) ).toFixed(8)
        ).toBe(
            actualRepayAmount.dividedBy(1e18).toFixed(8)
        )

        // The user's borrow snapshot should be updated correctly.
        expect(
            BigNumber(aftUserState[3]).toFixed(8)
        ).toBe(
            BigNumber(0.0).toFixed(8)
        )
        const deltInterest = BigNumber(preInterestState[1]).times( aftPoolState.BlockNumber-prePoolState.BlockNumber )
        // Total borrow should be decreased correctly.
        expect(
            BigNumber(prePoolState.TotalBorrows)
                .times(deltInterest).dividedBy(BigNumber(ScaleFactor)).plus(BigNumber(prePoolState.TotalBorrows))
                .minus(curBorrow)
                .integerValue(BigNumber.ROUND_FLOOR).toFixed(8)
        ).toBe(
            BigNumber(aftPoolState.TotalBorrows).toFixed(8)
        )
    });

    it("Reserves should be calculated correctly in borrowing.", async () => {
        await RandomEvnMaker()

        const userAddr1 = await getAccountAddress("user1")
        //
        BigNumber.config({ DECIMAL_PLACES: 8 })
        const totalAmount = BigNumber("100.0")
        const depositAmount = BigNumber("100.0")
        const borrowAmount = BigNumber("50.0")
        const borrowAmountScaled = borrowAmount.times(ScaleFactor)
        await mintFlow( userAddr1, totalAmount.toFixed(8) )
        await supply( userAddr1, depositAmount.toFixed(8) )
        await borrow(userAddr1, borrowAmount.toFixed(8))
        await nextBlock()

        
        const preLocalBalance = await getFlowBalance(userAddr1)
        const prePoolState = await queryFlowTokenPoolState()
        const preUserState = await queryUserPoolState(userAddr1)
        const preInterestState = await queryFlowTokenInterestRate(
            BigNumber(prePoolState.TotalCash).toNumber(),
            BigNumber(prePoolState.TotalBorrows).toNumber(),
            BigNumber(prePoolState.TotalReserves).toNumber()
        )
        
        //
        await nextBlock()
        
        const aftLocalBalance = await getFlowBalance(userAddr1)
        const aftPoolState = await queryFlowTokenPoolState()
        const aftUserState = await queryUserPoolState(userAddr1)

        const accrueRes = CalculateAccrueInterest(prePoolState, aftPoolState.BlockNumber, preInterestState)

        // Reserves should be calculated correctly.
        expect(
            accrueRes.TotalReserves.integerValue(BigNumber.ROUND_FLOOR).toFixed(8)
        ).toBe(
            BigNumber(aftPoolState.TotalReserves).toFixed(8)
        )
    });
});