import OracleInterface from "./OracleInterface.cdc"

// A simple centralized oracle maintained by the team. Admin can grant updateData role to other managed accounts.
pub contract SimpleOracle: OracleInterface {
    // The storage path for the Admin resource
    pub let AdminStoragePath: StoragePath
    // The storage path for the Oracle resource
    pub let OracleStoragePath: StoragePath
    // The private path for the capability to Oracle resource for admin to modify feeds
    pub let OraclePrivatePath: PrivatePath
    // The public path for the capability to restricted to &{OracleInterface.Getter}
    pub let OraclePublicPath: PublicPath

    // The storage path for updater's OracleUpdateProxy resource
    pub let UpdaterStoragePath: StoragePath
    // The public path for updater's OracleUpdateProxy capability
    pub let UpdaterPublicPath: PublicPath

    pub event PriceFeedAdded(for newYToken: Address, maxCapacity: Int)
    pub event PriceFeedRemoved(from newYToken: Address)
    pub event DataUpdated(for yToken: Address, at timestamp: UFix64, data: UFix64)

    // A single data point the off-chain oracle node reports.
    pub struct Observation {
        pub let timestamp: UFix64
        pub let priceData: UFix64

        init(timestamp: UFix64, data: UFix64) {
            self.timestamp = timestamp
            self.priceData = data
        }
    }

    // Use RingBuffer to store reported data points (i.e. the Observation).
    // We don't want to store infinity data on-chain since storing data on flow consumes account storage.
    pub resource RingBuffer {
        // Points to the next enqueue position
        access(self) var tail: Int
        access(all) let capacity: Int
        access(all) let dataType: Type
        access(self) let data: [AnyStruct]
        
        init(capacity: Int, dataType: Type) {
            self.capacity = capacity
            self.tail = 0
            self.dataType = dataType
            self.data = []
        }

        pub fun isEmpty(): Bool {
            return self.data.length == 0
        }

        pub fun isFull(): Bool {
            return self.data.length == self.capacity
        }

        // Return the last enqueued item.
        // Note: Caller ensures that the buffer is not empty.
        pub fun peek(): AnyStruct {
            let index = self.tail == 0 ? self.capacity - 1 : self.tail - 1
            return self.data[index]
        }

        // Insert data into tail then update pointers
        pub fun enqueue(_ item: AnyStruct) {
            if (item.isInstance(self.dataType)) {
                if (self.isFull()) {
                    self.data[self.tail] = item
                } else {
                    self.data.append(item)
                }
                self.tail = (self.tail + 1) % self.capacity
            } else {
                panic("Data type mismatch, expected: "
                    .concat(self.dataType.identifier)
                    .concat(", given: ")
                    .concat(item.getType().identifier)
                )
            }
        }
    }

    pub resource interface DataUpdater {
        access(contract) fun updatePrice(yToken: Address, data: UFix64)
    }

    pub resource Oracle: OracleInterface.Getter, DataUpdater {
        access(self) let feeds: [Address]
        // { yToken : Oracle data for yToken }
        access(self) let observations: @{Address: RingBuffer}

        // Return the underlying asset price denominated in USD.
        // Return 0.0 means price feed for the given yToken is not available.  
        pub fun getUnderlyingPrice(yToken: Address): UFix64 {
            if (!self.feeds.contains(yToken)) {
                return 0.0
            }
            return self.latestResult(yToken: yToken)[1]
        }

        // Return yToken's latest data point in form of (timestamp, data)
        pub fun latestResult(yToken: Address): [UFix64; 2] {
            let dataRef: &RingBuffer = &self.observations[yToken] as &RingBuffer
            if (dataRef == nil || dataRef.isEmpty()) {
                return [0.0, 0.0]
            }
            let latestData = dataRef.peek() as! Observation
            return [
                latestData.timestamp,
                latestData.priceData
            ]
        }

        access(contract) fun addPriceFeed(for newYToken: Address, maxCapacity: Int) {
            if (!self.feeds.contains(newYToken)) {
                // 1. Append new feed
                self.feeds.append(newYToken)
                // 2. Create RingBuffer resource to hold new feed's data
                let oldData <- self.observations[newYToken] <- create RingBuffer(capacity: maxCapacity, dataType: Type<Observation>())
                destroy oldData
                emit PriceFeedAdded(for: newYToken, maxCapacity: maxCapacity)
            }

        }

        access(contract) fun removePriceFeed(yToken: Address) {
            if (self.feeds.contains(yToken)) {
                // 1. Remove yToken from data feeds
                var idx = 0
                while idx < self.feeds.length {
                    if (self.feeds[idx] == yToken) {
                        break
                    }
                    idx = idx + 1
                }
                let lastToken = self.feeds.removeLast()
                if (lastToken != yToken) {
                    self.feeds[idx] = lastToken
                }
                // 2. Remove yToken's associated data
                let oldData <- self.observations.remove(key: yToken)
                destroy oldData
                emit PriceFeedRemoved(from: yToken)
            }
        }

        access(contract) fun updatePrice(yToken: Address, data: UFix64) {
            if (self.feeds.contains(yToken)) {
                let dataRef: &RingBuffer = &self.observations[yToken] as &RingBuffer
                let now = getCurrentBlock().timestamp
                dataRef.enqueue(Observation(timestamp: now, data: data))
                emit DataUpdated(for: yToken, at: now, data: data)
            }
        }

        init () {
            self.feeds = []
            self.observations <- {}
        }

        destroy() {
            destroy self.observations
        }
    }

    pub resource interface OracleUpdateProxyPublic {
        pub fun isUpdaterCapabilitySet(): Bool
        pub fun setUpdaterCapability(cap: Capability<&Oracle{DataUpdater}>)
    }

    // Other accounts holding OracleUpdateProxy resource can be granted with oracle DataUpdater Capability by Admin.
    pub resource OracleUpdateProxy: OracleUpdateProxyPublic {
        // Nobody else can copy the capability and use it.
        access(self) var updateCapability: Capability<&Oracle{DataUpdater}>?

        pub fun isUpdaterCapabilitySet(): Bool {
            return self.updateCapability != nil
        }

        // Only Admin can grant oracle DataUpdater capability so the type system guarantees it to be called only by Admin.
        pub fun setUpdaterCapability(cap: Capability<&Oracle{DataUpdater}>) {
            self.updateCapability = cap
        }

        pub fun update(yToken: Address, data: UFix64) {
            self.updateCapability!.borrow()!.updatePrice(yToken: yToken, data: data)
        }

        init() {
            self.updateCapability = nil
        }
    }

    // Anyone can call this, but OracleUpdateProxy cannot update oracle without Oracle capability,
    // which can only be given by Admin.
    pub fun createUpdateProxy(): @OracleUpdateProxy {
        return <- create OracleUpdateProxy()
    }

    pub resource Admin {
        // Creating an Oracle resource which holds @maxCapacity data points at most.
        pub fun createOracleResource(): @Oracle {
            return <- create Oracle()
        }
        // Admin can update data points directly, however, we also want to grant update rights to specific accounts
        // (i.e. off-chain oracle clients), so as not to expose admin private key in any condition.
        pub fun update(oracleCap: Capability<&Oracle>, yToken: Address, data: UFix64) {
            oracleCap.borrow()!.updatePrice(yToken: yToken, data: data)
        }
        pub fun addPriceFeed(oracleCap: Capability<&Oracle>, yToken: Address, capacity: Int) {
            oracleCap.borrow()!.addPriceFeed(for: yToken, maxCapacity: capacity)
        }
        pub fun removePriceFeed(oracleCap: Capability<&Oracle>, yToken: Address) {
            oracleCap.borrow()!.removePriceFeed(yToken: yToken)
        }
    }

    init() {
        self.AdminStoragePath = /storage/oracleAdmin
        self.OracleStoragePath = /storage/oracleModule
        self.OraclePrivatePath = /private/oracleModule
        self.OraclePublicPath = /public/oracleModule
        self.UpdaterStoragePath = /storage/oracleUpdaterProxy
        self.UpdaterPublicPath = /public/oracleUpdaterProxy

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
}