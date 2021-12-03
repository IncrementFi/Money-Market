import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

pub fun main(poolAddr: Address): {String: AnyStruct} {

    let poolPublicCap = getAccount(poolAddr).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow()
        ?? panic(
            Config.ErrorEncode (
                msg: "Invalid pool capability.",
                err: Config.Error.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
            )
        )
    let interestRateAddress = poolPublicCap.getInterestRateModelAddress()

    let interestRateModelRef = getAccount(interestRateAddress)
        .getCapability<&{Interfaces.InterestRateModelPublic}>(Config.InterestRateModelPublicPath)
        .borrow() ?? panic(
            Config.ErrorEncode (
                msg: "Invalid interest rate model capability.",
                err: Config.Error.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
            )
        )
    
    return interestRateModelRef.getInterestRateModelParams()
}