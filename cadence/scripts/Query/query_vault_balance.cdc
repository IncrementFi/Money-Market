import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"

access(all) fun main(userAddr: Address, vaultPath: PublicPath): UFix64 {
    let vaultBalCap = getAccount(userAddr).capabilities.get<&{FungibleToken.Balance}>(vaultPath)
    if vaultBalCap.check() == false || vaultBalCap.borrow() == nil {
        return 0.0
    }
    return vaultBalCap.borrow()!.balance
}