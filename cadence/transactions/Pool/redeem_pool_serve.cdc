import LendingPool from 0x16b25c744f20f313
import FungibleToken from 0x9a0766d93b6608b7

transaction(amount: UFix64, receiverAddr: Address) {

    let PoolAdminRef: &LendingPool.PoolAdmin

    prepare(poolAccount: AuthAccount) {
        self.PoolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath) ?? panic("Lost pool admin.")
    }

    execute {
        let reserveVault <- self.PoolAdminRef.withdrawReserves(reduceAmount: amount)
        getAccount(receiverAddr).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver).borrow()!.deposit(from: <-reserveVault)
    }
}