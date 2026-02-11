# User Guide 与应用交互流程

## 📊 完整交互架构

```
┌─────────────────────────────────────────────────────────┐
│              用户指南中的操作说明                          │
│          (User Guide - 场景1: 创建Vault并铸造STB)       │
└────────────────┬────────────────────────────────────────┘
                 │ 用户按照指南操作
                 ▼
┌─────────────────────────────────────────────────────────┐
│                  前端应用 (React)                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Header 组件                                      │   │
│  │ • 连接钱包 (Wagmi + MetaMask)                    │   │
│  │ • 显示账户地址                                   │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Dashboard 组件                                   │   │
│  │ • 从 ContractContext 读取用户 Vault 数据        │   │
│  │ • 显示: 抵押、债务、抵押率、健康度               │   │
│  │ • 调用 refresh() 定时刷新数据                    │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ActionPanel 组件 ⬅️ 用户在此操作                │   │
│  │ • 4个标签页: Deposit / Mint / Repay / Withdraw   │   │
│  │ • 用户选择 "Deposit" 标签                        │   │
│  │ • 输入 WETH 数量 (e.g., 10)                     │   │
│  │ • 实时预计抵押率: 400% (显示为绿色 = Safe)     │   │
│  │ • 点击 "Deposit ETH" 按钮                       │   │
│  │   → 调用 performAction('deposit', 10)           │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ LiquidationDemo 组件                            │   │
│  │ • 显示清液历史和演示清液                         │   │
│  └─────────────────────────────────────────────────┘   │
└────────────┬────────────────────────────────────────────┘
             │ performAction() 中的 Web3 交互
             ▼
┌─────────────────────────────────────────────────────────┐
│           ContractContext (数据和交互管理)              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ performAction() 函数处理4种操作:               │   │
│  │                                                  │   │
│  │ 1. Deposit                                       │   │
│  │    → stableVault.deposit(amount)                │   │
│  │    → 写入交易: 用户WETH → 合约                  │   │
│  │                                                  │   │
│  │ 2. Mint                                          │   │
│  │    → stableVault.mint(amount)                   │   │
│  │    → 写入交易: 合约铸造STB给用户                │   │
│  │    → 检查oracle.canRiskActionProceed()          │   │
│  │                                                  │   │
│  │ 3. Repay                                         │   │
│  │    → stbToken.approve(stableVault, amount)     │   │
│  │    → stableVault.repay(amount)                  │   │
│  │    → 写入交易: 用户STB → 合约销毁              │   │
│  │                                                  │   │
│  │ 4. Withdraw                                      │   │
│  │    → stableVault.withdraw(amount)               │   │
│  │    → 写入交易: 合约WETH → 用户                  │   │
│  │                                                  │   │
│  │ refresh() 读取用户当前Vault状态:               │   │
│  │  • getVault(userAddress)                        │   │
│  │  • getCollateralRatioBps(userAddress)           │   │
│  │  • getPriceStatus() (从oracle)                  │   │
│  └─────────────────────────────────────────────────┘   │
└────────────┬────────────────────────────────────────────┘
             │ RPC 调用 (ethers.js / viem)
             ▼
┌─────────────────────────────────────────────────────────┐
│         智能合约 (Solidity on Sepolia)                 │
│                                                         │
│ StableVault.sol                                        │
│  ├─ deposit(amount)                                    │
│  │   └─ 接收WETH，记录到 vaults[user]                 │
│  │   └─ emit Deposited(user, amount)                  │
│  │                                                     │
│  ├─ mint(amount)                                       │
│  │   ├─ 调用 oracleHub.canRiskActionProceed()        │
│  │   ├─ 增加 vault.debtPrincipal                      │
│  │   ├─ 检查 _requireHealthy() → CR > 150%           │
│  │   └─ STBToken.mint(user, amount)                   │
│  │   └─ emit Minted(user, amount)                     │
│  │                                                     │
│  ├─ repay(amount)                                      │
│  │   ├─ 接收STB token (transferFrom)                  │
│  │   ├─ 计算稳定费 (年化4%)                           │
│  │   ├─ 更新 vault.debtPrincipal                      │
│  │   └─ STBToken.burn()                               │
│  │   └─ emit Repaid(user, amount, feePaid)           │
│  │                                                     │
│  ├─ withdraw(amount)                                   │
│  │   ├─ 减少 vault.collateralAmount                   │
│  │   ├─ 检查 _requireHealthy() → CR > 150%           │
│  │   └─ 转账WETH给用户                                │
│  │   └─ emit Withdrawn(user, amount)                  │
│  │                                                     │
│  └─ liquidate(owner, repayAmount) 🤖 [由Keeper调用]  │
│      ├─ 检查 isLiquidatable() → CR < 150%            │
│      ├─ 计算清液额度 (受maxCloseFactor限制)          │
│      ├─ 计算清液奖励 (8%)                             │
│      ├─ 转账WETH给liquidator                          │
│      └─ 更新坏账记录                                  │
│                                                         │
│ OracleHub.sol                                          │
│  └─ getPriceStatus()                                  │
│     └─ 返回 [effectivePrice, spotPrice, twapPrice]  │
│     └─ 检查断路器 (偏差 > 20%? return false)        │
│                                                         │
│ TwapOracle.sol                                         │
│  └─ updateTwap(priceE18) [由TWAP Worker调用]        │
│     └─ 接收后端发来的加权平均价格                     │
│                                                         │
│ STBToken.sol (ERC20)                                  │
│  ├─ mint(to, amount) [仅StableVault可调用]           │
│  ├─ burn(from, amount) [仅StableVault可调用]         │
│  └─ transfer/approve (标准ERC20)                     │
└────────────┬────────────────────────────────────────────┘
             │ 交易记录到区块链、事件发出
             ▼
┌─────────────────────────────────────────────────────────┐
│            后端服务 (监听和数据处理)                    │
│                                                         │
│ Indexer Worker                                         │
│  ├─ 监听 Deposited / Withdrawn 事件                   │
│  ├─ 监听 Minted / Repaid 事件                         │
│  ├─ 监听 Liquidated 事件                              │
│  └─ 更新数据库 vault_state 表:                        │
│     ├─ owner, collateral, debt                        │
│     ├─ health: 'safe'|'warning'|'danger'             │
│     └─ updatedAt                                      │
│                                                         │
│ Keeper Worker 🤖                                       │
│  ├─ 定期扫描: SELECT * FROM vault_state               │
│  │           WHERE health IN ('danger', 'warning')    │
│  ├─ 对每个危险Vault执行清液:                         │
│  │  └─ stableVault.liquidate(owner, repayAmount)    │
│  │  └─ 带重试机制 + 指数退避                         │
│  └─ 记录 keeper_status:                              │
│     ├─ lastRunAt, scanned, succeeded                 │
│     └─ recentFailures                                 │
│                                                         │
│ TWAP Worker                                            │
│  ├─ 每次tick采样 Chainlink 现货价格                   │
│  ├─ 计算时间窗口内的加权平均价格                      │
│  ├─ 调用 twapOracle.updateTwap(computed)             │
│  └─ 存储 oracle_sample 表:                           │
│     ├─ source: 'spot'|'twap'                         │
│     ├─ price, staleness, deviation                   │
│     └─ sampledAt                                      │
│                                                         │
│ REST API Server                                        │
│  ├─ GET /health                    ← 前端定时检查    │
│  ├─ GET /v1/protocol/metrics       ← Dashboard读取   │
│  ├─ GET /v1/oracle/status          ← Dashboard读取   │
│  ├─ GET /v1/vaults/:owner          ← 查询单个Vault  │
│  ├─ GET /v1/vaults?health=danger   ← 查询危险Vault  │
│  ├─ GET /v1/liquidations           ← 清液历史      │
│  └─ GET /v1/keeper/status          ← Keeper状态     │
└────────────┬────────────────────────────────────────────┘
             │ SQLite数据库存储数据
             ▼
┌─────────────────────────────────────────────────────────┐
│              数据库 (SQLite + Prisma)                  │
│  • vault_state        - Vault当前状态快照              │
│  • liquidation_event  - 历史清液事件                   │
│  • oracle_sample      - 价格采样历史                   │
│  • keeper_status      - Keeper运行状态                 │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 详细交互流程示例

### 场景 1：用户按照 User Guide 存入 10 WETH 并铸造 5000 STB

#### 步骤 1: 用户连接钱包
```
用户界面: Header 组件 → "Connect Wallet" 按钮
↓
MetaMask 弹窗
↓
用户确认连接
↓
前端获得: address = 0x1234...
```

#### 步骤 2: 前端显示 Dashboard
```
ContractContext.refresh() 被调用:
  1. 读取 stableVault.getVault(0x1234...)
     → 返回 [collateral=0, debt=0, ...]
  2. 读取 oracleHub.getPriceStatus()
     → 返回 [effectivePrice=$2500, ...]
  3. setData({ collateral: 0, debt: 0, ... })

Dashboard 显示:
  • ETH Price: $2500
  • Collateral: 0 ETH
  • Debt: 0 STB
  • Collateral Ratio: ∞ (无债务)
  • Health Factor: Safe (绿色)
```

#### 步骤 3: 用户在 ActionPanel 执行 Deposit

**用户操作**：
```
ActionPanel 标签页: "Deposit" (已选)
  ↓
  输入框: 10 (WETH 数量)
  ↓
  实时计算:
    projectedCollateral = 0 + 10 = 10 ETH
    projectedDebt = 0 STB (未改变)
    projectedCR = ∞ (无债务)
    显示: "∞ %" (绿色 Safe)
  ↓
  点击按钮 "Deposit ETH"
```

**前端代码执行**：
```typescript
// ActionPanel.tsx 中的 handleAction()
performAction('deposit', 10)
  ↓
// ContractContext.tsx 中的 performAction()
case 'deposit':
  const tx = await stableVault.deposit({ value: parseUnits('10', 18) })
  await tx.wait()
  ↓
// 交易发送到 Sepolia 网络
```

**智能合约执行**：
```solidity
// StableVault.sol 中的 deposit()
function deposit() external payable {
    Vault storage vault = vaults[msg.sender];  // msg.sender = 0x1234...
    vault.collateralAmount += msg.value;       // 增加 10e18 wei
    emit Deposited(msg.sender, msg.value);     // 发出事件
}

// 链上状态变化:
// vaults[0x1234...].collateralAmount = 10e18 wei (10 WETH)
```

**后端 Indexer 监听**：
```typescript
// indexer.ts
监听 Deposited 事件:
  owner = 0x1234...
  ethAmount = 10e18

// snapshot.ts 中的 refreshVaultSnapshot()
更新数据库:
  INSERT/UPDATE vault_state
  SET owner = '0x1234...'
      collateral = '10'
      health = 'safe'
      updatedAt = NOW()
```

**前端刷新数据**：
```typescript
// 用户点击后立即 await refresh()

publicClient.readContract({
  address: CONTRACTS.stableVault,
  functionName: 'getVault',
  args: [0x1234...]
  // 返回 [10e18, 0, 0, 0, 0]
})

setData({
  collateral: 10,
  debt: 0,
  collateralRatio: ∞,
  healthFactor: 'Safe'
})

// Dashboard 立即更新:
// • Collateral: 10 ETH ≈ $25,000
// • Debt: 0 STB
// • Collateral Ratio: ∞%
```

---

#### 步骤 4: 用户切换到 Mint 标签页并铸造 5000 STB

**用户操作**：
```
ActionPanel 切换到: "Mint"
  ↓
  输入框: 5000 (STB 数量)
  ↓
  实时计算:
    projectedCollateral = 10 ETH (不变)
    projectedDebt = 0 + 5000 = 5000 STB
    projectedCR = (10 × $2500) / 5000 × 100 = 500%
    显示: "500%" (绿色 Safe，因为 > 170%)
  ↓
  点击按钮 "Mint STB"
```

**前端代码执行**：
```typescript
performAction('mint', 5000)
  ↓
case 'mint':
  const tx = await stableVault.mint(parseUnits('5000', 18))
  await tx.wait()
```

**智能合约执行**：
```solidity
function mint(uint256 stbAmount) external whenNotPaused {
    Vault storage vault = vaults[msg.sender];  // 0x1234...
    
    // 检查断路器
    if (!oracleHub.canRiskActionProceed()) revert OracleBreaker();
    
    vault.debtPrincipal += stbAmount;           // 增加 5000e18
    
    // 检查健康度: CR > 150%
    uint256 ratio = (vault.collateralAmount * price) / vault.debtPrincipal;
    if (ratio < 150 * 1e18 / 100) revert InsufficientCollateral();
    
    stb.mint(msg.sender, stbAmount);            // 铸造5000 STB给用户
    emit Minted(msg.sender, stbAmount);
}

// 链上状态变化:
// vaults[0x1234...].debtPrincipal = 5000e18
// STBToken.balanceOf[0x1234...] += 5000e18
```

**后端更新**：
```typescript
// Indexer 监听 Minted 事件
// snapshot 更新:
UPDATE vault_state
SET debt = '5000'
    collateral_ratio = 500
    health = 'safe'
```

**前端显示**：
```
Dashboard 更新:
  • Debt: 5000 STB
  • Collateral Ratio: 500%
  • Health Factor: Safe (绿色)

用户现在拥有:
  • 抵押品: 10 WETH (已锁定在StableVault)
  • 债务: 5000 STB (已转账到用户账户)
  • 钱包: 拥有 5000 STB
```

---

### 场景 2：价格下跌至 $1500，用户面临清液风险

#### 价格变化流程

**链上发生**：
```
Chainlink 聚合器更新:
  ETH/USD = $1500 (从 $2500 下跌)
```

**后端 TWAP Worker 处理**：
```typescript
// twapWorker.ts 的 runTwapTick()
1. 读取 Chainlink 现货价格: $1500
2. 样本数据库记录最近的价格
3. 计算时间窗口内的加权平均价格
4. 假设计算结果: TWAP = $1450

// 调用链上更新
twapOracle.updateTwap(1450e18)

// OracleHub.getPriceStatus() 现在返回:
[
  effectivePrice: $1450,
  spotPrice: $1500,
  twapPrice: $1450,
  breakerTriggered: false (因为偏差 < 20%)
]
```

**前端获取新价格**：
```typescript
// ContractContext.refresh()
publicClient.readContract({
  address: CONTRACTS.oracleHub,
  functionName: 'getPriceStatus'
  // 返回 [1450e18, 1500e18, 1450e18, ..., false]
})

setEthPrice(1450)
setData({
  collateral: 10,
  debt: 5000,
  collateralRatio: (10 × 1450) / 5000 × 100 = 290%,
  healthFactor: 'Safe' (仍然 > 170%)
})

// Dashboard 显示:
// • ETH Price: $1500 (更新)
// • Collateral Ratio: 290% (下降，但仍Safe)
```

---

#### 继续下跌至 $800

**后端 Indexer 和 Keeper 反应**：
```typescript
// 新抵押率 = (10 × 800) / 5000 × 100 = 160%

// indexer/snapshot.ts 计算健康度:
if (collateralRatio < 150%) health = 'danger'
else if (collateralRatio < 170%) health = 'warning'

// vault_state 更新:
UPDATE vault_state
SET collateral_ratio = 160
    health = 'warning'  ⚠️
```

**Keeper 自动监测**：
```typescript
// keeperWorker.ts 的主循环
const candidates = await listVaultCandidates()
// SELECT * FROM vault_state
// WHERE health IN ('danger', 'warning')
// 返回: [{ owner: '0x1234...', health: 'warning', ... }]

// Keeper 选择是否清液
// 因为还有 160% > 150% 的缓冲，暂不清液
// 但持续监控...
```

**前端告警**：
```
Dashboard 显示:
  • ETH Price: $800 (暴跌)
  • Collateral Ratio: 160% (危险)
  • Health Factor: Warning ⚠️ (黄色)
  • 距离清液: 0% (0.8 - 0.75 / 0.8) × 100

ActionPanel 中:
  • 如果用户尝试 Mint，会显示抵押率变为 160% 以下 (红色)
```

---

#### 继续下跌至 $700（触发清液）

**触发条件**：
```
新抵押率 = (10 × 700) / 5000 × 100 = 140%
140% < 150% (最小抵押率)
→ Vault 变为 'danger'
```

**后端 Keeper 自动执行清液**：
```typescript
// keeperWorker.ts
const candidates = await listVaultCandidates()
// 返回包含 '0x1234...'，其中 health = 'danger'

await liquidateWithRetry({
  owner: '0x1234...',
  repayAmount: bigint,  // 计算部分债务
  liquidate: (owner, repayAmount) => 
    stableVault.liquidate(owner, repayAmount),
  maxAttempts: 2,
  baseBackoffMs: 500
})

// 清液交易发送:
tx = await stableVault.liquidate(
  '0x1234...',    // ownerAddress
  repayAmount     // 由合约计算
)
await tx.wait()
```

**智能合约执行清液**：
```solidity
function liquidate(address ownerAddress, uint256 repayAmount) {
    Vault storage vault = vaults[ownerAddress];
    
    // 计算目标清液额度（恢复到 170%）
    uint256 targetRepay = _computeRepayForTarget(vault);
    // 目标: 使得 CR = 170%
    // 170% = (10 × 700 - seizedCollateral × 700) / (5000 - repayAmount) × 100
    // 求解: repayAmount ≈ 833 STB, seizedCollateral ≈ 1.2 WETH
    
    // 计算清液奖励 (8%)
    uint256 seizeCollateral = (repayAmount × 108) / 100 / price;
    // seizeCollateral = 833 × 1.08 / 700 ≈ 1.28 WETH
    
    // 清液人支付 833 STB，获得 1.28 WETH
    stb.transferFrom(liquidator, address(this), 833e18);
    stb.burn(address(this), 833e18);  // 销毁主债
    
    vault.collateralAmount -= seizeCollateral;     // 10 → 8.72
    vault.debtPrincipal -= repayAmount;            // 5000 → 4167
    
    payable(liquidator).transfer(seizeCollateral); // 转账给清液人
    
    emit Liquidated(ownerAddress, liquidator, 833e18, seizeCollateral, 0);
}

// 清液后 Vault 状态:
// vaults[0x1234...].collateral = 8.72 WETH
// vaults[0x1234...].debt = 4167 STB
// 新 CR = (8.72 × 700) / 4167 × 100 ≈ 147% (略低于150%)
//    → 仍有清液风险，可能继续清液...
```

**后端更新**：
```typescript
// Indexer 监听 Liquidated 事件
liquidationEvent = {
  owner: '0x1234...',
  liquidator: '0xKeeper...',
  repayAmount: 833e18,
  seizedCollateral: 1.28e18,
  badDebtDelta: 0
}

INSERT liquidation_event VALUES (...)

// snapshot 更新:
UPDATE vault_state
SET collateral = 8.72
    debt = 4167
    collateral_ratio = 147
    health = 'danger'  // 仍然危险
    updatedAt = NOW()
```

**前端显示清液结果**：
```
Dashboard 更新:
  • 用户的 Vault 状态:
    ├─ Collateral: 8.72 ETH
    ├─ Debt: 4167 STB
    ├─ Collateral Ratio: 147%
    └─ Health Factor: Danger (红色)
  
  • 清液历史:
    └─ 清液事件: 
       ├─ 清液人地址
       ├─ 清液 833 STB
       ├─ 夺取 1.28 WETH (含8%奖励)
       └─ 时间戳

LiquidationDemo 中会显示这个清液事件
```

---

## 🎯 User Guide 中各个功能点的代码映射

| User Guide 章节 | 前端组件 | 后端 API | 智能合约 |
|---|---|---|---|
| **存入WETH** | ActionPanel.tsx (Deposit tab) | 无 | StableVault.deposit() |
| **铸造STB** | ActionPanel.tsx (Mint tab) | 无 | StableVault.mint() |
| **还款** | ActionPanel.tsx (Repay tab) | 无 | StableVault.repay() |
| **提取WETH** | ActionPanel.tsx (Withdraw tab) | 无 | StableVault.withdraw() |
| **仪表板** | Dashboard.tsx | /v1/protocol/metrics<br>/v1/oracle/status | getVault()<br>getPriceStatus() |
| **清液演示** | LiquidationDemo.tsx | /v1/liquidations<br>/v1/keeper/status | liquidate() |
| **健康度评分** | Dashboard.tsx<br>ActionPanel.tsx | /v1/vaults/:owner | getCollateralRatioBps() |
| **预言机状态** | Dashboard.tsx | /v1/oracle/status | OracleHub.getPriceStatus() |

---

## 📱 数据流向总结

```
用户操作 (前端)
    ↓
ContractContext.performAction()
    ↓
Web3 写入交易 (wagmi / viem)
    ↓
智能合约执行 (Solidity)
    ↓
事件发出 (Deposited / Minted / Repaid 等)
    ↓
后端 Indexer 监听事件
    ↓
数据库更新 (SQLite)
    ↓
ContractContext.refresh() 定时读取
    ↓
前端组件重新渲染 (React)
    ↓
用户看到最新数据
```

**自动化路径** (无需用户操作):
```
Keeper Worker 定期扫描
    ↓
发现危险 Vault (CR < 150%)
    ↓
自动执行 liquidate() 交易
    ↓
事件记录到数据库
    ↓
前端从 /v1/liquidations 读取历史
    ↓
LiquidationDemo 显示清液事件
```

---

## 🔧 配置和环境变量的作用

### 前端 `.env`
```env
VITE_STABLE_VAULT_ADDRESS=0x...    # 合约地址
VITE_RPC_URL=...                   # RPC 节点 → Web3 调用
VITE_BACKEND_BASE_URL=...          # 后端 API 地址 → API 调用
```

### 后端 `.env`
```env
STABLE_VAULT_ADDRESS=0x...         # 监听此地址的事件
RPC_URL=...                         # 连接到 Sepolia
KEEPER_ADDRESS=0x...               # 清液机器人账户
KEEPER_MAX_ATTEMPTS=2              # 清液重试次数
TWAP_WINDOW_SECONDS=3600           # TWAP 时间窗口
```

### 合约 `.env`
```env
PRIVATE_KEY=...                    # 部署者私钥
RPC_URL=...                         # 部署到 Sepolia
CHAINLINK_ETH_USD=0x694AA...       # Chainlink 聚合器
WETH_ADDRESS=0x7b79...             # Sepolia WETH
KEEPER_ADDRESS=0x...               # 授权为 Keeper
```

这些环境变量确保了三层架构的联动。

