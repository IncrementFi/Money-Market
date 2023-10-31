import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"

transaction(feeTo: Address) {
    prepare(poolAccount: AuthAccount) {
        let poolPublic = getAccount(poolAccount.address).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow()
            ?? panic("cannot borrow reference to PoolPublic")
        let flowReceiverPath = /public/flowTokenReceiver
        let usdcReceiverPath = /public/USDCVaultReceiver
        let fusdReceiverPath = /public/fusdReceiver
        let stFlowReceiverPath = /public/stFlowTokenReceiver
        let bltReceiverPath = /public/bloctoTokenReceiver
        var receiverPath: PublicPath = /public/dummy
        switch poolPublic.getUnderlyingTypeString() {
            case "FlowToken":
                receiverPath = flowReceiverPath
            case "FiatToken":
                receiverPath = usdcReceiverPath
            case "FUSD":
                receiverPath = fusdReceiverPath
            case "stFlowToken":
                receiverPath = stFlowReceiverPath
            case "BloctoToken":
                receiverPath = bltReceiverPath
            default:
                panic("non-supported LendingPool")
        }

        let tokenReceiverRef = getAccount(feeTo).getCapability(receiverPath).borrow<&{FungibleToken.Receiver}>()
            ?? panic("cannot borrow receiver reference to the recipient's Vault")
        let poolAdmin = poolAccount.borrow<&{LendingInterfaces.PoolAdminPublic}>(from: /storage/incrementLendingPoolAdmin)
            ?? panic("cannot borrow reference to pool admin")
        tokenReceiverRef.deposit(from: <-poolAdmin.withdrawReserves(reduceAmount: UFix64.max))
    }
}