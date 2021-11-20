
## Tips:
1. 一些scripts和transactions是自动生成的，请先运行multipool-deploy.sh
2. 合约返回的所有number，都是被scale up的，需要除以1e18，前端暂时显示小数点后8位。
3. 一些当前borrow limit的计算请使用参数实时计算（比如用户输入不同的deposit金额时）
4. 前端显示和前端计算用到的价格数据都从外部api读取，比如：https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=bitcoin,ethereum,flow


## JS-api
* TODO


## Scripts
#### 查询所有pool的address，返回 [address1, address2, address3]，Input: 固定Comptroller地址
* flow scripts execute ./cadence/scripts/Query/query_pool_all_address.cdc 0xf8d6e0586b0a20c7
#### 按address查询pool的info (total supply, APY, total borrow, borrow APY 等等)，Input: poolAddr, 固定Comptroller地址
* flow scripts execute ./cadence/scripts/Query/query_pool_info.cdc 0x192440c99cb17282 0xf8d6e0586b0a20c7

#### 查询有用户记录的所有pool的address，输入userAddr, 固定的comptroller地址
flow scripts execute ./cadence/scripts/Query/query_user_pool_all_address.cdc e03daebed8ca0615 0xf8d6e0586b0a20c7
#### 查询用户在特定pool下的信息(存款，借款)，输入userAddr, poolAddr, 固定的comptroller地址
flow scripts execute ./cadence/scripts/Query/query_user_pool_info.cdc e03daebed8ca0615 0x192440c99cb17282 0xf8d6e0586b0a20c7

#### 查询用户本地underlying vault的余额
* FUSD的是: flow scripts execute ./cadence/scripts/Query/autogen/query_local_FUSD.cdc e03daebed8ca0615
* 通用模板:  flow scripts execute ./cadence/scripts/Query/autogen/query_local_TokenName.cdc e03daebed8ca0615
    >每个underlying vault会对应一个接口
    >>想吐槽找Flow X.X



## Transactions
#### 水龙头:
* FlowToken: flow transactions send ./cadence/transactions/Test/emulator_flow_transfer.cdc 0x收款地址 --signer emulator-account
* FUSD: flow transactions send ./cadence/transactions/Test/mint_fusd_for_user.cdc --signer emulator-user-A --arg UFix64:"100.0"
* 假Token: flow transactions send ./cadence/transactions/Test/autogen/mint_Token名字_for_user.cdc -f flow_multipool.json --signer emulator-user-A

#### 存钱，以FUSD举例，通用模板只需要替换文件名token标识
* flow transactions send ./cadence/transactions/User/autogen/user_deposit_FUSD.cdc -f flow_multipool.json --arg UFix64:"10.0" --signer emulator-user-A

#### 取钱
* flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json --arg UFix64:"1.0" --signer emulator-user-A
    >传入 UFix64.max 或者 184467440737.09551615 取出全部
    >flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json --arg UFix64:"184467440737.09551615" --signer emulator-user-A
    >>每个underlying vault会对应一个接口

#### 借钱
* flow transactions send ./cadence/transactions/User/autogen/user_borrow_FUSD.cdc -f flow_multipool.json --arg UFix64:"2.0" --signer emulator-user-A

#### 还钱
* flow transactions send ./cadence/transactions/User/autogen/user_repay_FUSD.cdc -f flow_multipool.json --arg UFix64:"184467440737.09551615" --signer emulator-user-A
    >传入 UFix64.max 或者 184467440737.09551615 全部还清

#### test next block
* flow transactions send ./cadence/transactions/Test/test_next_block.cdc

#### 这些池子的文件名模板举例：
* user_deposit_FUSD.cdc
* user_deposit_FlowToken.cdc
* user_deposit_Apple.cdc
* user_deposit_Banana.cdc




## 以下废弃：
#### query整个产品的balance (total supply & total borrow)
* flow scripts execute ./cadence/scripts/Query/query_universe_balance.cdc
利用返回的每个pool的supple和usd的汇率计算加和

#### query用户名下当前的存款美元量, 借款美元量, Net APY, 抵押率 (UI有高刷新率)
* flow scripts execute ./cadence/scripts/Query/query_user_total_balance.cdc 0x01cf0e2f2f715450
total的前端加和

#### 用户开启 关闭 pool collateral
* 打开fusd开关
* flow transactions send ./cadence/transactions/User/user_collateral_fusd.cdc --arg Bool:"true" --signer emulatorA
* flow transactions send ./cadence/transactions/User/user_collateral_fusd.cdc --arg Bool:"false" --signer emulatorA
    >如果直接borrow, 默认会自动打开




