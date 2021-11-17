
## 所有query的return json都定义在 /cadence/contracts/IncQueryInterface.cdc中

## Scripts
#### query池子的信息 (total supply, APY, total borrow, borrow APY 等等)
* flow scripts execute ./cadence/scripts/Query/query_pool_all_infos.cdc
* flow scripts execute ./cadence/scripts/Query/query_pool_info.cdc 0xf8d6e0586b0a20c7

#### query整个产品的balance (total supply & total borrow)
* flow scripts execute ./cadence/scripts/Query/query_universe_balance.cdc

#### query用户名下当前的存款美元量, 借款美元量, Net APY, 抵押率 (UI有高刷新率)
* flow scripts execute ./cadence/scripts/Query/query_user_total_balance.cdc 0x01cf0e2f2f715450

#### query用户各个pool下的信息(存款量, 等值美元量, APY, 是否开启) (借款量, 等值美元量, 借APY, 抵押率)
* flow scripts execute ./cadence/scripts/Query/query_user_pool_supply.cdc 0x01cf0e2f2f715450
* flow scripts execute ./cadence/scripts/Query/query_user_pool_borrow.cdc 0x01cf0e2f2f715450

#### query用户本地underlying vault的余额
* flow scripts execute ./cadence/scripts/Query/query_local_fusd.cdc 0x01cf0e2f2f715450
* flow scripts execute ./cadence/scripts/Query/query_local_flow.cdc 0x01cf0e2f2f715450
* flow scripts execute ./cadence/scripts/Query/query_local_kibble.cdc 0x01cf0e2f2f715450
    >每个underlying vault会对应一个接口
    >>想吐槽找Flow X.X

#### 页面的一些borrow limit计算 (比如用户在deposit输入存款数额时), 请使用info中的对应oracle价格估算


### Transactions
#### 用户开启 关闭 pool collateral
* 打开fusd开关
* flow transactions send ./cadence/transactions/User/user_collateral_fusd.cdc --arg Bool:"true" --signer emulatorA
* flow transactions send ./cadence/transactions/User/user_collateral_fusd.cdc --arg Bool:"false" --signer emulatorA
    >如果直接borrow, 默认会自动打开

#### Faucet FUSD:
* flow transactions send ./cadence/transactions/Test/test_mint_fusd.cdc --signer emulatorA

#### 存钱
* flow transactions send ./cadence/transactions/User/user_deposit_fusd.cdc --arg UFix64:"5.0" --signer emulatorA
    >每个underlying vault会对应一个接口

#### 取钱
* flow transactions send ./cadence/transactions/User/user_redeem_fusd.cdc --arg UFix64:"4.0" --signer emulatorA
    >传入 UFix64.max 或者 184467440737.09551615 取出全部
    >>每个underlying vault会对应一个接口

#### 借钱
* flow transactions send ./cadence/transactions/User/user_borrow_fusd.cdc --arg UFix64:"2.0" --signer emulatorA

#### 还钱
* flow transactions send ./cadence/transactions/User/user_repay_fusd.cdc --arg UFix64:"2.0" --signer emulatorA
    >传入 UFix64.max 或者 184467440737.09551615 全部还清



