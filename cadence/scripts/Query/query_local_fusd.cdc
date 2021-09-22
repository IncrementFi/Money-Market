import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

pub fun main(userAddr: Address): UFix64 {
    let fusdBalance = getAccount(userAddr).getCapability<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance)
    if fusdBalance.check() == false || fusdBalance.borrow() == nil {
        return 0.0
    }
    return fusdBalance.borrow()!.balance
}