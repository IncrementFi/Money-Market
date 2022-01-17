import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingError from "../../contracts/LendingError.cdc"
// Return: (cross-market collateral value in usd; cross-market borrows in usd)
// LTV ratio = ret[1] / ret[0]
pub fun main(userAddr: Address, comptrollerAddr: Address): [String; 3] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath).borrow()
        ?? panic(
            LendingError.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: LendingError.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    let res = comptrollerRef.getUserCrossMarketLiquidity(userAddr: userAddr)
    return res
}