import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

// Return: (cross-market collateral value in usd; cross-market borrows in usd)
// LTV ratio = ret[1] / ret[0]
pub fun main(userAddr: Address, comptrollerAddr: Address): [String; 2] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()
        ?? panic("cannot borrow reference to comptroller")
    let res = comptrollerRef.getUserCrossMarketLiquidity(userAddr: userAddr)
    return res
}