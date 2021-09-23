import FungibleToken from "./FungibleToken.cdc"
import LedgerToken from "./LedgerToken.cdc"

pub contract interface IncPoolInterface {

    pub resource interface PoolPublic {
        pub fun queryBorrowBalanceSnapshot(userAddr: Address): UFix64
        pub fun queryBorrowBalanceRealtime(userAddr: Address): UFix64
        
        pub fun depositExplicitly   (inUnderlyingVault: @FungibleToken.Vault, outOverlyingVaultCap: Capability<&{LedgerToken.IdentityReceiver}>)
        //pub fun deposit             (inUnderlyingVault: @FungibleToken.Vault, outOverlyingVaultCap: Capability<&{LedgerToken.IdentityReceiver}>)
        pub fun redeemExplicitly    (redeemOverlyingAmount: UFix64, identityCap: Capability<&{LedgerToken.IdentityReceiver}>, outUnderlyingVaultCap: Capability<&{FungibleToken.Receiver}>)
        pub fun borrow              (amountUnderlyingBorrow: UFix64, identityCaps: [Capability<&{LedgerToken.IdentityReceiver}>], outUnderlyingVaultCap: Capability<&{FungibleToken.Receiver}>)
        pub fun repayBorrow         (repayUnderlyingVault: @FungibleToken.Vault, borrowerAddr: Address)
        
        //
        pub fun openCollateral(open: Bool, identityCap: Capability<&{LedgerToken.IdentityReceiver}>)
    }

    pub resource interface PoolPrivate {
        pub let overlyingType:  Type
        pub let underlyingType: Type
        pub let overlyingName:  String
        pub let underlyingName: String
        pub var isOpen:         Bool
        pub var canDeposit:     Bool
        pub var canRedeem:    Bool
        pub var canBorrow:      Bool
        
        pub fun queryBorrowBalanceSnapshot(userAddr: Address): UFix64
        pub fun queryCollateralFactor(): UFix64
        pub fun queryOverlyingBalance(userAddr: Address): UFix64
        pub fun queryExchange(): UFix64
        pub fun queryBorrowIndex(): UFix64
        pub fun queryComptrollerUuid(): UInt64
        pub fun queryOpenCollateral(userAddr: Address): Bool

        pub fun repayBorrow(repayUnderlyingVault: @FungibleToken.Vault, borrowerAddr: Address)
        pub fun seizeInternal(seizeOverlyingAmount: UFix64, borrowerAddr: Address, outOverlyingVaultCap: Capability<&{LedgerToken.IdentityReceiver}>)
        pub fun accrueInterest()
        
        pub fun openPool(_ open: Bool)
        pub fun checkUserLocalVaultIdentityCap(userAddr: Address): Bool
    }

    pub resource interface PoolTokenInterface {
        pub fun checkUserLiquidity(userAddr: Address, testRedeemAmount: UFix64, testBorrowAmount: UFix64): [UFix64]
        pub fun checkUserLocalVaultIdentityCap(userAddr: Address): Bool
    }

}