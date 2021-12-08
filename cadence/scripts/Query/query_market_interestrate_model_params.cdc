import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"
import Error from "../../contracts/Error.cdc"

pub fun main(poolAddr: Address): {String: AnyStruct} {

    let poolPublicCap = getAccount(poolAddr).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow()
        ?? panic(
            Error.ErrorEncode (
                msg: "Invalid pool capability.",
                err: Error.ErrorCode.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
            )
        )
    let interestRateAddress = poolPublicCap.getInterestRateModelAddress()

    let interestRateModelRef = getAccount(interestRateAddress)
        .getCapability<&{Interfaces.InterestRateModelPublic}>(Config.InterestRateModelPublicPath)
        .borrow() ?? panic(
            Error.ErrorEncode (
                msg: "Invalid interest rate model capability.",
                err: Error.ErrorCode.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
            )
        )
    
    return interestRateModelRef.getInterestRateModelParams()
}