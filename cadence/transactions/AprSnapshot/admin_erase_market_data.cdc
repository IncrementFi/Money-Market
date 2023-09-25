import LendingAprSnapshot from "../../contracts/LendingAprSnapshot.cdc"

// LendingAprSnapshot's Admin erases stored apr data of the given lending market and stop tracking
transaction(poolAddr: Address) {
    prepare(aprDataAdmin: AuthAccount) {
        let aprAdminRef = aprDataAdmin.borrow<&LendingAprSnapshot.Admin>(from: LendingAprSnapshot.AdminStoragePath)
            ?? panic("Lost AprSnapshot admin")
        aprAdminRef.eraseMarketData(poolAddr: poolAddr)
    }
}