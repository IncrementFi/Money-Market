import IncPoolInterface from "./IncPoolInterface.cdc"
import IncQueryInterface from "./IncQueryInterface.cdc"
import LedgerToken from "./LedgerToken.cdc"
import FungibleToken from "./FungibleToken.cdc"

pub contract interface IncComptrollerInterface {

    pub resource interface ComptrollerPublic {
        pub fun applyForPoolList(poolCap: Capability<&{IncPoolInterface.PoolPrivate}>)

        pub fun queryBorrowBalanceInPool(poolAddr: Address, userAddr: Address): UFix64
        pub fun queryPoolInfo(poolAddr: Address): IncQueryInterface.PoolInfo
        pub fun queryAllPoolInfos(): [IncQueryInterface.PoolInfo]
        pub fun queryUniverseBalance(): IncQueryInterface.UniverseBalance
        pub fun queryUserBalance(userAddr: Address): IncQueryInterface.UserBalance
        pub fun queryUserPoolSupplyInfo(userAddr: Address): [IncQueryInterface.UserPoolInfo]
        pub fun queryUserPoolBorrowInfo(userAddr: Address): [IncQueryInterface.UserPoolInfo]
            

        pub fun liquidate(
            borrower: Address,
            repayPoolAddr: Address,
            seizePoolAddr: Address,
            outOverlyingVaultCap: Capability<&{LedgerToken.PrivateCertificate}>,
            repayUnderlyingVault: @FungibleToken.Vault
        )
    }

    pub resource interface ComptrollerPrivate {
    }

    
}
    