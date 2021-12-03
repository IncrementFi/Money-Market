
## Tips:
1. 请先运行./scripts/multipool-deploy.sh
   root下会生成deploy.config.emulator.json配置
   如果需要在emulator上模拟多个池子，请修改: ./scripts/emulator/multipool_setting.py
2. onflow版本有更新，type的版本请更新到0.0.6，"@onflow/types": "^0.0.6"
3. 合约返回的所有number，都是被scale up的，需要除以1e18，前端暂时显示小数点后8位。
4. 一些当前borrow limit的计算请使用参数实时计算（比如用户输入不同的deposit金额时）
5. 前端显示和前端计算用到的价格数据都从外部api读取，比如：https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=bitcoin,ethereum,flow


## JS-api
* TODO

## Error Code:
> 如果Flow合约的错误返回是字符串，正则匹配出ErrorCode 或是 ErrorMsg
> ErrorCode的描述json在 ./increment.errorcode.json
```js
  var msg = "xx[IncErrorMsg:Invailid comptroller cap.][IncErrorCode:5]xx"
  var reg_increment_error = /\[IncErrorMsg:(.*)\]\[IncErrorCode:(\d+)\]/
  var reg_cadence_error = /error:(.*)/

  res = msg.match(reg_increment_error)
  if(res != null) {
      // 这是上层合约能捕捉到的错误代码
      var incrementErrorMsg = res[1]
      var incrementErrorCode = res[2]
      // check this error code in increment.errorcode.json
      
  } else {
      // 底层的错误msg，可能暂时无法捕捉
      res = msg.match(reg_cadence_error)
      if(res != null) {
          var cadenceErrorMsg = res[1]
      }
  }
```

## Scripts
#### 查询所有pool的address
> input: Comptroller地址
> output: [pool1_address, pool2_address, pool3_address]
* flow scripts execute ./cadence/scripts/Query/query_all_markets.cdc 0xf8d6e0586b0a20c7

#### 查询pool的相关信息 (total supply, APY, total borrow, borrow APY 等等)
> input: poolAddr, Comptroller地址
> output: json
  返回json中需要注意的是: marketType字段是string类型，比如：“A.XXXXX_FUSD”，它的字符串结尾以‘_’可以切割出token的名称
* flow scripts execute ./cadence/scripts/Query/query_market_info.cdc 0x192440c99cb17282 0xf8d6e0586b0a20c7

#### 查询pool 利率模型参数，用于利率模型曲线绘制:
> input: poolAddr
> output: json
* 代码:  deploy.config.emulator.json --> Codes.scripts.QueryMarketInterestRateModelParams  0x192440c99cb17282

#### 查询用户有参与的所有pool的地址
> input: userAddr, comptroller地址
> output: [pooladdr1, pooladdr2]
* flow scripts execute ./cadence/scripts/Query/query_user_all_pools.cdc e03daebed8ca0615 0xf8d6e0586b0a20c7

#### 查询用户在特定pool下的信息(存款，借款)
> input: userAddr, poolAddr, comptroller地址
> output: json, 包含用户在该pool里的supply和borrow的underlying token数量
* flow scripts execute ./cadence/scripts/Query/query_user_pool_info.cdc e03daebed8ca0615 0x192440c99cb17282 0xf8d6e0586b0a20c7

#### 查询用户本地underlying vault的余额
> input: userAddr, vaultPublicPath
* FUSD: flow scripts execute ./cadence/scripts/Query/query_vault_balance.cdc --args-json '[{"type": "Address", "value": "0x045a1763c93006ca"}, {"type": "Path", "value": {"domain": "public", "identifier": "fusdBalance"}}]'

#### 查询用户名下的最新的totalSupply与totalBorrow
> input: userAddr, comptroller地址
flow scripts execute ./cadence/scripts/Query/query_user_position.cdc 0x045a1763c93006ca 0xf8d6e0586b0a20c7


## Transactions
#### 水龙头:
* FlowToken: flow transactions send ./cadence/transactions/Test/emulator_flow_transfer.cdc --arg Address:0xe03daebed8ca0615 --arg UFix64:"100.0" --signer emulator-account
* FUSD: flow transactions send ./cadence/transactions/Test/mint_fusd_for_user.cdc --signer emulator-user-A --arg UFix64:"100.0"
* 伪造的临时Token: flow transactions send ./cadence/transactions/Test/autogen/mint_Token名字_for_user.cdc -f flow_multipool.json --signer emulator-user-A

#### 存钱
1. transaction模板: ./cadence/transactions/User/user_borrow_template.cdc
2. 首先通过scripts接口获取到每个pool的地址和token名称后，比如: 0x192440c99cb17282 FUSD
3. 模板替换规则: 以Apple举例
    a. TokenName替换:  FlowToken -> Apple
    b. tokenName替换:  flowToken -> apple (FUSD特殊规则 fusd)
    c. LendingPool替换: 在emulator时，需要替换成: LendingPool_Apple
* Cli接口可直接使用本地生成的临时代码:
* flow transactions send ./cadence/transactions/User/autogen/user_deposit_FUSD.cdc -f flow_multipool.json --arg UFix64:"10.0" --signer emulator-user-A

#### 取钱
* 模板: ./cadence/transactions/User/user_redeem_template.cdc
  替换规则同deposit
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
> Input: comptrollerAddress
* flow transactions send ./cadence/transactions/Test/test_next_block.cdc --signer emulator-account


## 利率模型曲线绘制:
利用QueryMarketInterestRateModelParams接口获取到的利率模型参数之后:
```js
{
    "modelName": Name,
    "blocksPerYear": B,
    "scaleFactor": 放大因子 (1e18),
    "scaledBaseRatePerBlock": 基础利率,
    "scaledBaseMultiplierPerBlock": 一段斜率,
    "scaledJumpMultiplierPerBlock": 二段斜率,
    "scaledCriticalUtilRate": 折线拐点使用率
}
```
1. 使用率 = borrows / (cash + borrows - reserves)
2. borrow曲线公式:
X轴: 当前使用率
Y轴: 
a. 如果 X <= 折线拐点使用率:
> Y = (一段斜率 * X / 放大因子 + 基础利率)
b. 如果 X > 折线拐点使用率:
> Y = (X - 折线拐点使用率) * 二段斜率 / 放大因子 + 一段斜率 * 折线拐点使用率 / 放大因子 + 基础利率

3. supply曲线公式:
X轴: 当前使用率
Borrow利率 = BorrowRate(X) [上面的公式]
Reserve因子 = 取自pool info接口的 "marketReserveFactor"参数
Y轴: 
> Y = (放大因子 - Reserve因子) * Borrow利率 / 放大因子 * X / 放大因子