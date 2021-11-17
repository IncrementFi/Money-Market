#!/bin/bash

##### Interest Rate Model
echo "---- 1// Create InterestRateModel resource"
flow transactions send cadence/transactions/InterestRateModel/create_interest_rate_model.cdc --args-json '[{"type": "String", "value": "TwoSegmentsInterestRateModel"}, {"type": "UInt64", "value": "315360"}, {"type": "UFix64", "value": "0.0"}, {"type": "UFix64", "value": "0.05"}, {"type": "UFix64", "value": "0.35"}, {"type": "UFix64", "value": "0.8"}]' --signer emulator-account
echo "---- 2// Check model parameters:"
flow scripts execute cadence/scripts/InterestRateModel/get_model_params.cdc --args-json '[{"type": "Address", "value": "0xf8d6e0586b0a20c7"}]'