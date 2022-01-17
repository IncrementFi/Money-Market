import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingError from "../../contracts/LendingError.cdc"

pub fun main(poolAddr: Address): {String: AnyStruct} {

    let poolPublicCap = getAccount(poolAddr).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow()
        ?? panic(
            LendingError.ErrorEncode (
                msg: "Invalid pool capability.",
                err: LendingError.ErrorCode.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
            )
        )
    let interestRateAddress = poolPublicCap.getInterestRateModelAddress()

    let interestRateModelRef = getAccount(interestRateAddress)
        .getCapability<&{LendingInterfaces.InterestRateModelPublic}>(LendingConfig.InterestRateModelPublicPath)
        .borrow() ?? panic(
            LendingError.ErrorEncode (
                msg: "Invalid interest rate model capability.",
                err: LendingError.ErrorCode.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
            )
        )
    
    return interestRateModelRef.getInterestRateModelParams()
}