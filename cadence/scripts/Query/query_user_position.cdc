import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import Config from "../../contracts/Config.cdc"
import Error from "../../contracts/Error.cdc"
// Return: (cross-market collateral value in usd; cross-market borrows in usd)
// LTV ratio = ret[1] / ret[0]
pub fun main(userAddr: Address, comptrollerAddr: Address): [String; 3] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()
        ?? panic(
            Error.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Error.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    let res = comptrollerRef.getUserCrossMarketLiquidity(userAddr: userAddr)
    return res
}