import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

pub fun main(): {String: AnyStruct} {
    var res:{String: AnyStruct} = {
        "BlockNumber": LendingPool.accrualBlockNumber.toString(),
        "BorrowIndex": LendingPool.scaledBorrowIndex.toString(),
        "TotalBorrows": LendingPool.scaledTotalBorrows.toString(),
        "TotalReserves": LendingPool.scaledTotalReserves.toString(),
        "TotalSupply": LendingPool.scaledTotalSupply.toString(),
        "ReserveFactor": LendingPool.scaledReserveFactor.toString(),
        "PoolSeizeShare": LendingPool.scaledPoolSeizeShare.toString(),
        "TotalCash": LendingPool.getPoolCash().toString(),
        "LpTokenMintRate": LendingPool.underlyingToLpTokenRateSnapshotScaled().toString()
    }
    return res
}