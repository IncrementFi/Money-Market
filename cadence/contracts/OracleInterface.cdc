pub contract interface OracleInterface {
    pub resource interface Getter {
        // Get the given yToken's underlying asset price denominated in USD.
        // Return value of 0.0 means the given yToken price feed is not available.
        pub fun getUnderlyingPrice(yToken: Address): UFix64

        // Return latest reported data in [timestamp, priceData]
        pub fun latestResult(yToken: Address): [UFix64; 2]
    }
}