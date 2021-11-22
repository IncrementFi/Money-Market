import FungibleToken from "../../contracts/FungibleToken.cdc"

pub fun main(userAddr: Address, vaultPath: PublicPath): UFix64 {
    let vaultBalance = getAccount(userAddr).getCapability<&{FungibleToken.Balance}>(vaultPath)
    if vaultBalance.check() == false || vaultBalance.borrow() == nil {
        log(0.0)
        return 0.0
    }
    log(vaultBalance.borrow()!.balance)
    return vaultBalance.borrow()!.balance
}