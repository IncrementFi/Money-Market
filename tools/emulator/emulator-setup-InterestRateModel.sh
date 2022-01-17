#!/bin/bash

##### Interest Rate Model
echo "---- 1// Create InterestRateModel resource"
flow transactions send cadence/transactions/InterestRateModel/create_interest_rate_model.cdc --args-json '[{"type": "String", "value": "TwoSegmentsInterestRateModelV1"}, {"type": "UInt256", "value": "12614400"}, {"type": "UInt256", "value": "0"}, {"type": "UInt256", "value": "50000000000000000"}, {"type": "UInt256", "value": "350000000000000000"}, {"type": "UInt256", "value": "800000000000000000"}]' --signer emulator-account
echo "---- 2// Check model parameters:"
flow scripts execute cadence/scripts/InterestRateModel/get_model_params.cdc --args-json '[{"type": "Address", "value": "0xf8d6e0586b0a20c7"}]'
