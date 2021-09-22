import FungibleToken from "./FungibleToken.cdc"

pub contract interface LedgerToken {

    pub struct VaultInfo {
        pub var balance: UFix64
        pub var originalOwner: Address?
    }
    access(contract) let ledger: {UInt64:VaultInfo}
    // TODO events

    //
    //
    pub resource interface Balance {
        pub var balance: UFix64
        pub fun updateBalance()
        pub fun getLedgerBalance(): UFix64
        init(balance: UFix64) {
            pre {
                self.getLedgerBalance() == 0.0: "Duplicate vault, will never happen."
            }
            post {
                self.balance == self.getLedgerBalance(): "Ledger balance != local balance after init."
            }
        }
    }

    pub resource interface Receiver {
        pub var balance: UFix64
        pub let underlyingTokenType: Type
        pub fun getLedgerBalance(): UFix64
        pub fun deposit(from: @FungibleToken.Vault) {
            post {
                self.getLedgerBalance() == before(self.getLedgerBalance()) + before(from.balance): "New Vault balance must be the sum of the previous balance and the deposited Vault"
                self.balance == self.getLedgerBalance(): "Ledger balance != local balance after deposit."
            }
        }
    }

    pub resource interface Provider {
        pub var balance: UFix64
        pub fun getLedgerBalance(): UFix64
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.getLedgerBalance() >= amount: "Ledger amount < withdraw amount."
            }
            post {
                self.balance == self.getLedgerBalance(): "Ledger balance != local balance after withdraw."
                self.getLedgerBalance() == before(self.getLedgerBalance()) - amount: "New Vault balance must be the difference of the previous balance and the withdrawn Vault"
            }
        }
    }


    pub resource interface PrivateCertificate {
        pub var balance: UFix64
        pub let underlyingTokenType: Type

        pub fun deposit(from: @FungibleToken.Vault)
        pub fun getLedgerBalance(): UFix64
        pub fun updateBalance()
        pub fun getInfo(): VaultInfo
    }

    pub resource Minter {
        pub fun mintTokens(amount: UFix64): @FungibleToken.Vault
    }
    
    pub resource LedgerManager {
        pub fun withdraw(amount: UFix64, fromUuid: UInt64): @FungibleToken.Vault
        pub fun setVaultOriginalOwner(uuid: UInt64, owner: Address)

        pub fun queryBalance(vaultId: UInt64): UFix64
    }
}