import LendingAprSnapshot from "../../contracts/LendingAprSnapshot.cdc"

// LendingAprSnapshot's Admin starts tracking apr data of the given lending market
transaction(poolAddr: Address) {
    prepare(aprDataAdmin: AuthAccount) {
        let aprAdminRef = aprDataAdmin.borrow<&LendingAprSnapshot.Admin>(from: LendingAprSnapshot.AdminStoragePath)
            ?? panic("Lost AprSnapshot admin")
        aprAdminRef.trackMarketData(poolAddr: poolAddr)
    }
}