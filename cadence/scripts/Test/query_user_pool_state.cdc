import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"

pub fun main(poolAddr: Address, userAddr: Address): [String;5] {
    let poolRef = getAccount(poolAddr).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow()!
    let res = poolRef.getAccountSnapshotScaled(account: userAddr)
    return [res[0].toString(), res[1].toString(), res[2].toString(), res[3].toString(), res[4].toString()]
}