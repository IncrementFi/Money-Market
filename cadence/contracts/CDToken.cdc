import FungibleToken from "./FungibleToken.cdc"
import LedgerToken from "./LedgerToken.cdc"
import IncPoolInterface from "./IncPoolInterface.cdc"

// Certificate of Deposite token
pub contract CDToken: FungibleToken, LedgerToken {
    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)
    pub event TokensMinted(amount: UFix64)
    pub event MinterCreated()
    //
    pub event LedgerVaultMisbehaved(uuid: UInt64, balanceLedger: UFix64, balanceLocal: UFix64, owner: Address?)
    //
    
    pub let Admin_StoragePath: StoragePath
    pub let Minter_StoragePath: StoragePath
    pub let Minter_PrivatePath: PrivatePath

    pub var MinterProxyFull_StoragePath: StoragePath
    pub var MinterProxyReceiver_PublicPath: PublicPath

    pub var VaultPath_Storage: StoragePath
    pub var VaultReceiverPath_Pub: PublicPath
    pub var VaultCollateralPath_Priv: PrivatePath
    
    //
    pub struct VaultInfo {
        pub var balance: UFix64
        pub var originalOwner: Address?  // 标识了此vault是否是用户开户的原始vault
        init(balance:UFix64) {
            self.balance = balance
            self.originalOwner = nil
        }
        access(contract) fun setBalance(_ n:UFix64) { self.balance = n }
        access(contract) fun addBalance(_ n:UFix64) { self.balance = self.balance + n }
        access(contract) fun subBalance(_ n:UFix64) { self.balance = self.balance - n }
        access(contract) fun setOriginalOwner(_ owner:Address) {
            if self.originalOwner == nil {
                self.originalOwner = owner
            }
        }
    }
    //
    pub var totalSupply: UFix64
    pub var underlyingTokenType: Type?
    pub var underlyingName: String
    access(contract) var poolCap: Capability<&{IncPoolInterface.PoolTokenInterface}>?
    access(contract) let ledger: {UInt64:LedgerToken.VaultInfo}
    //
    
    //
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, 
                        LedgerToken.Provider,   LedgerToken.Receiver,   LedgerToken.Balance,
                        LedgerToken.IdentityReceiver {
        //
        pub var balance: UFix64
        pub let underlyingTokenType: Type

        //
        pub fun getLedgerBalance(): UFix64 {
            if CDToken.ledger.containsKey(self.uuid) == false {
                return 0.0
            }
            return CDToken.ledger[self.uuid]!.balance
        }
        
        pub fun updateBalance() {
            let ledgerBalance = self.getLedgerBalance()
            if self.balance != ledgerBalance {
                emit LedgerVaultMisbehaved(uuid:self.uuid, balanceLedger:ledgerBalance, balanceLocal:self.balance, owner:self.owner?.address)
                self.balance = ledgerBalance
            }
        }


        pub fun getInfo(): LedgerToken.VaultInfo {
            let infoTmp = CDToken.ledger[self.uuid]!
            return infoTmp
        }

        init(balance: UFix64) {
            self.balance = balance
            CDToken.ledger[self.uuid] = VaultInfo(balance:balance)
            self.underlyingTokenType = CDToken.underlyingTokenType!
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.balance == self.getLedgerBalance(): "This vault lost IdentityReceiver capability, please call the updateBalance and re-connect the capability."
            }

            let originalOwner = self.getInfo().originalOwner
            // 如果此vault是作为用户的开户ctoken vault存在
            if originalOwner != nil {
                // 用户恶意移除了原先ctoken的vault or cap
                assert(CDToken.poolCap!.borrow()!.checkUserLocalVaultIdentityCap(userAddr: originalOwner!), message: "The original owner has misbehaviors on this vault.")

                // 不可以更改地址, 如果恶意移动, 无法withdraw
                // TODO 需要测试用例, 恶意转移withdraw
                assert(
                    self.owner != nil &&
                    self.owner!.address == originalOwner,
                    message: "This vault is a collateral vault of someone else and cannot be withdrawed."
                )
                let owner = self.owner!.address
                // 如果用户要提ctoken, 需要流动性检测
                let liquidtyRes = CDToken.poolCap!.borrow()!.checkUserLiquidity(
                    userAddr: owner,
                    testRedeemAmount: amount,
                    testBorrowAmount: 0.0
                )
                assert(liquidtyRes[1] == 0.0, message: "Liquidty is not enough after withdraw.")
            }

            self.balance = (self.balance - amount)

            (CDToken.ledger[self.uuid]! as! CDToken.VaultInfo).subBalance(amount)

            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            pre {
                self.balance == self.getLedgerBalance(): "This vault lost IdentityReceiver capability, please call the updateBalance and re-connect the capability."
            }

            let fromVault <- from as! @CDToken.Vault
            assert( self.underlyingTokenType == fromVault.underlyingTokenType, message: "Different CDToken type in deposit.")
            
            // TODO 需要测试用例, 恶意提款
            // 原始抵押vault不允许直接作为fromVault, 否则试图合入其他vault.
            assert(fromVault.getInfo().originalOwner == nil, message: "FromVault cannot be the collateral vault, please use withdraw to generate new vault.")
            
            self.balance = (self.balance + fromVault.balance)
            
            (CDToken.ledger[self.uuid]! as! CDToken.VaultInfo).addBalance(fromVault.balance)
            
            emit TokensDeposited(amount: fromVault.balance, to: self.owner?.address)
            
            (CDToken.ledger[fromVault.uuid]! as! CDToken.VaultInfo).setBalance(0.0)
            fromVault.balance = 0.0

            destroy fromVault
        }

        destroy() {
            self.updateBalance()
            if CDToken.totalSupply >= self.balance {
                CDToken.totalSupply = CDToken.totalSupply - self.balance
            } else {
                // TODO emit error
                CDToken.totalSupply = 0.0
            }
            // TODO 用户销毁GToken... 如果有欠款不让删除？
            CDToken.ledger.remove(key:self.uuid)

            log("销毁ctoken vault")
        }
    }
    //
    pub resource LedgerManager {
        pub fun withdraw(amount: UFix64, fromUuid: UInt64): @FungibleToken.Vault {
            pre {
                CDToken.ledger.containsKey(fromUuid): "withdraw invalid vault uuid."
                CDToken.ledger[fromUuid]!.balance >= amount: "Not enough balance in withdraw."
            }
            
            (CDToken.ledger[fromUuid]! as! CDToken.VaultInfo).subBalance(amount)
            log("中央账本withdraw ".concat(amount.toString()))
            let withdrawVault <- create Vault(balance: amount)

            // TODO event
            return <-withdrawVault
        }

        pub fun setVaultOriginalOwner(uuid: UInt64, owner: Address) {
            pre {
                CDToken.ledger.containsKey(uuid): "Unknow vauit uuid."
                // CDToken.ledger[uuid]!.originalOwner == nil: "Cannot reset the original owner."
            }
            log("设置 vault 原始 owner")
            (CDToken.ledger[uuid]! as! CDToken.VaultInfo).setOriginalOwner(owner)
        }

        pub fun queryBalance(vaultId: UInt64): UFix64 {
            if CDToken.ledger.containsKey(vaultId) == false { return 0.0 }
            return CDToken.ledger[vaultId]!.balance
        }
    }

    // TODO: CDToken can only be minted by pool.
    pub resource Minter {
        pub fun mintTokens(amount: UFix64): @CDToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
            }
            CDToken.totalSupply = CDToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }
    }

    pub resource interface MinterProxyReceiver {
        pub fun setMinterCapability(cap: Capability<&Minter>)
    }
    pub resource MinterProxy: MinterProxyReceiver {
        priv var minterCapability: Capability<&Minter>?
        pub fun setMinterCapability(cap: Capability<&Minter>) {
            self.minterCapability = cap
        }
        pub fun mintTokens(amount: UFix64): @CDToken.Vault {
            return <- self.minterCapability!.borrow()!.mintTokens(amount:amount)
        }
        init() {
            self.minterCapability = nil
        }

    }
    // TODO 如果恶意批量创建空vault侵占ledger存储
    pub fun createEmptyVault(): @CDToken.Vault {
        return <-create Vault(balance: 0.0)
    }
    
    pub fun createMinterProxy(): @MinterProxy {
        return <- create MinterProxy()
    }

    pub resource Administrator {
        pub fun createNewMinter(): @Minter {
            emit MinterCreated()
            return <- create Minter()
        }
        pub fun createLedgerManager(): @LedgerManager {
            // TODO event
            return <- create LedgerManager()
        }
        pub fun setPoolCap(poolCap: Capability<&{IncPoolInterface.PoolTokenInterface}>) {
            CDToken.poolCap = poolCap
        }
    }


    // TODO delete
    pub var minter_test: @Minter
    init() {
        self.Admin_StoragePath      = /storage/gtokenAdmin
        self.Minter_StoragePath     = /storage/gtokenMinter
        self.Minter_PrivatePath     = /private/gtokenMinter
        
        self.MinterProxyFull_StoragePath        = /storage/minterProxyFull
        self.MinterProxyReceiver_PublicPath     = /public/minterProxyReceiver
        self.VaultPath_Storage                  = /storage/nil
        self.VaultReceiverPath_Pub           = /public/nil
        self.VaultCollateralPath_Priv        = /private/nil
        //
        self.totalSupply                = 0.0
        self.ledger                     = {}
        self.underlyingTokenType        = nil
        self.underlyingName             = "nil"

        self.poolCap                    = nil
        
        // local minter
        //self.account.save(<-create Minter(), to: self.Minter_StoragePath)
        //self.account.link<&Minter>(self.Minter_PrivatePath, target: self.Minter_StoragePath)
        // local admin
        let admin <- create Administrator()
        self.account.save(<-admin, to: self.Admin_StoragePath)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: 0.0)

        // TODO test
        self.minter_test <- create Minter()
    }

    pub fun bind(
        underlyingName: String,
        underlyingTokenType: Type,
        MinterProxyFull_StoragePath: StoragePath,
        MinterProxyReceiver_PublicPath: PublicPath,
        VaultPath_Storage: StoragePath,
        VaultReceiverPath_Pub: PublicPath,
        VaultCollateralPath_Priv: PrivatePath
    ) {
        pre {
            self.underlyingTokenType == nil: "Cannot rebind."
        }
        self.underlyingName                 = underlyingName
        self.underlyingTokenType            = underlyingTokenType
        self.MinterProxyFull_StoragePath    = MinterProxyFull_StoragePath
        self.MinterProxyReceiver_PublicPath = MinterProxyReceiver_PublicPath
        self.VaultPath_Storage              = VaultPath_Storage
        self.VaultReceiverPath_Pub          = VaultReceiverPath_Pub
        self.VaultCollateralPath_Priv       = VaultCollateralPath_Priv
    }
}
