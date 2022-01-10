// Admin needs to keep track of updaterCapability paths.
transaction() {
    prepare(adminAccount: AuthAccount) {
        // Note!: Admin needs to keep track of updaterCapability paths.
        let updaterCapPath: CapabilityPath = /private/oracleUpdater_001
        adminAccount.unlink(updaterCapPath)
    }
}