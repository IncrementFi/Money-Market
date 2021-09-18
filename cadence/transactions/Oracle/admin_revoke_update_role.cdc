// Admin needs to keep track of updaterCapability paths.
// @updaterCapPath: e.g. /private/oracleUpdater_001
transaction(updaterCapPath: CapabilityPath) {
    prepare(adminAccount: AuthAccount) {
        adminAccount.unlink(updaterCapPath)
    }
}