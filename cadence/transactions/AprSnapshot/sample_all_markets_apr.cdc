
import LendingAprSnapshot from "../../contracts/LendingAprSnapshot.cdc"
import LendingComptroller from "../../contracts/LendingComptroller.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"

// Bot periodically sample all lending markets' apr data and store them on-chain. 
transaction() {
    prepare(bot: AuthAccount) {
        let comptrollerRef = getAccount(LendingComptroller.comptrollerAddress).getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath).borrow()
            ?? panic("cannot borrow reference to ComptrollerPublic")

        let poolArrays = comptrollerRef.getAllMarkets()
        for poolAddr in poolArrays {
            let sampled = LendingAprSnapshot.sample(poolAddr: poolAddr)
        }
    }
}