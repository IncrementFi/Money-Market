import SimpleOracle from "../../contracts/SimpleOracle.cdc"

transaction(updater: Address) {
    let capabilityPrivatePath: CapabilityPath
    let updaterCapability: Capability<&SimpleOracle.Oracle{SimpleOracle.DataUpdater}>

    prepare(adminAccount: AuthAccount) {
        // Note: Admin needs to keep track of updaterCapability paths
        self.capabilityPrivatePath = /private/oracleUpdater_001
        self.updaterCapability = adminAccount.link<&SimpleOracle.Oracle{SimpleOracle.DataUpdater}>(
            self.capabilityPrivatePath,
            target: SimpleOracle.OracleStoragePath
        ) ?? panic("Could not create private updateCapability linked to Oracle resource")
    }

    execute {
        let capabilityReceiver = getAccount(updater)
            .getCapability<&SimpleOracle.OracleUpdateProxy{SimpleOracle.OracleUpdateProxyPublic}>(SimpleOracle.UpdaterPublicPath)
            .borrow() ?? panic("Could not borrow reference to updater")

        capabilityReceiver.setUpdaterCapability(cap: self.updaterCapability)
    }
}