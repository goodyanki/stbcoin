# StableVault 用户指南

## 📌 目录

1. [项目简介](#项目简介)
2. [系统要求](#系统要求)
3. [快速开始](#快速开始)
4. [功能说明](#功能说明)
5. [操作指南](#操作指南)
6. [常见问题](#常见问题)
7. [架构概览](#架构概览)

---

## 项目简介

**StableVault** 是一个部署在 Sepolia 测试网上的**过度抵押型稳定币协议 MVP**。

### 核心特性

- ✅ **WETH 抵押机制** - 用户存入 WETH 作为抵押品
- ✅ **STB 稳定币铸造** - 根据抵押率铸造等额的 STB 稳定币
- ✅ **自动化清算** - 当抵押不足时，Keeper 自动执行清算
- ✅ **双重预言机** - Chainlink 现货价格 + TWAP 价格验证
- ✅ **REST API** - 实时查询协议数据
- ✅ **Web UI** - 友好的交互界面

---

## 系统要求

### 软件环境

| 工具 | 版本 | 用途 |
|------|------|------|
| Node.js | 20+ | 后端服务和前端构建 |
| npm | 最新 | 包管理器 |
| Foundry | 最新 | 智能合约编译和部署 |
| Git | - | 版本控制 |

### 安装步骤

```bash
# 检查 Node.js 版本
node --version    # 应该 >= v20.0.0
npm --version

# 检查 Foundry
forge --version

# 如果未安装 Foundry，运行
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 网络要求

- 需要 **Sepolia 测试网 RPC 节点** 访问权限
- 推荐使用 Alchemy、Infura 或其他公开 RPC

---

## 快速开始

### 第一步：获取源码

```bash
git clone https://github.com/goodyanki/stbcoin.git
cd stbcoin
```

### 第二步：部署智能合约

```bash
cd contracts

# 复制环境配置文件
cp .env.example .env

# 编辑 .env，设置以下内容：
# PRIVATE_KEY=你的私钥（Sepolia 账户）
# RPC_URL=你的 RPC 地址
# CHAINLINK_ETH_USD=0x694AA1769357215DE4FAC081bf1f309adC325306  # Sepolia Chainlink
# WETH_ADDRESS=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9      # Sepolia WETH

# 部署合约
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify

# ✅ 记下输出的合约地址，后面需要用到
```

### 第三步：启动后端服务

```bash
cd ../backend

# 复制环境配置
cp .env.example .env

# 编辑 .env，填入第二步获得的合约地址：
# STABLE_VAULT_ADDRESS=0x...
# STB_TOKEN_ADDRESS=0x...
# ORACLE_HUB_ADDRESS=0x...
# TWAP_ORACLE_ADDRESS=0x...
# RPC_URL=你的 RPC 地址
# KEEPER_ADDRESS=清算机器人地址（可选）

# 安装依赖
npm install

# 初始化数据库
npx prisma generate
npx prisma migrate dev --name init

# 启动后端（会自动启动 Indexer、Keeper、TWAP Worker）
npm run dev

# 输出应包含：
# ✅ Server running on http://localhost:3000
# ✅ indexer backfill started
# ✅ indexer subscribe started
# ✅ twap worker started
# ✅ keeper worker started
```

### 第四步：启动前端

```bash
cd ../frontend

# 复制环境配置
cp .env.example .env

# 编辑 .env，填入合约地址和前端配置：
# VITE_STABLE_VAULT_ADDRESS=0x...
# VITE_RPC_URL=你的 RPC 地址
# VITE_CHAIN_ID=11155111  # Sepolia

# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 访问 http://localhost:5173
```

### 验证部署

```bash
# 检查后端 API
curl http://localhost:3000/health
# 应返回 { "status": "ok" }

# 检查协议指标
curl http://localhost:3000/v1/protocol/metrics
```

---

## 功能说明

### 1. 存入 WETH 和铸造 STB

**用途**：创建一个自己的金库（Vault），存入 WETH 作为抵押品，然后铸造等额的 STB 稳定币。

**前置条件**：
- 连接钱包到 Sepolia
- 拥有 WETH（可以从水龙头获取）
- 足够的 gas 费用

**流程**：
1. 在前端 "ActionPanel" 选择 "Deposit"
2. 输入 WETH 数量，点击 "Deposit"
3. 钱包确认交易
4. 确认后，您的 Vault 中就有了抵押品
5. 现在可以在 "Mint" 中铸造 STB（最多可铸造抵押品 1/2 的价值）

**抵押率计算**：
$$\text{抵押率} = \frac{\text{抵押 WETH 价值（美元）}}{\text{STB 债务金额}} \times 100\%$$

- **最小安全率**：> 150% （可正常操作）
- **警告级别**：150% ~ 170% （建议补充抵押）
- **清算危险**：< 150% （随时可能被清算）

### 2. 还款和提取

**用途**：偿还 STB 债务并取回 WETH 抵押品。

**流程**：
1. 在前端 "ActionPanel" 选择 "Repay"
2. 输入想要还款的 STB 数量
3. 钱包确认，交易完成后债务会减少
4. 选择 "Withdraw" 取回多余的 WETH

**注意事项**：
- 还款会支付**稳定费**（按年化 4% 计算）
- 只有还清所有债务后才能全部提取 WETH
- 提取时保证抵押率 > 150%

### 3. 仪表板（Dashboard）

**显示内容**：

| 指标 | 说明 |
|------|------|
| **您的 Vault** | 抵押金额、债务、健康度评分 |
| **协议总览** | 总抵押、总 STB 发行量、平均抵押率 |
| **预言机状态** | Chainlink 现货价格、TWAP 价格、偏差 |
| **清算历史** | 最近的清算事件 |

### 4. 清液演示（LiquidationDemo）

**仅限演示用途**：手动触发清算，观察清算过程。

**清液逻辑**：
- 当 Vault 抵押率 < 150% 时，任何人都可以清算它
- 清算人支付部分债务，获得相应抵押物 + 8% 奖励
- 被清算的 Vault 恢复到 170% 抵押率

---

## 操作指南

### 常见操作流程

#### 场景 1：我想创建一个 Vault

```
1. 前端 → ActionPanel → Deposit
2. 输入 WETH 数量（如 10 WETH）
3. 确认交易
4. 现在您有了 10 WETH 的抵押品
5. Mint → 输入想铸造的 STB 数量（如 5000 STB）
6. 确认交易完成
```

**您的 Vault 状态**：
- 抵押：10 WETH ≈ $20,000（假设 ETH=$2000）
- 债务：5000 STB
- 抵押率：400%（非常安全）

#### 场景 2：市场下跌，我需要补充抵押品

```
价格下跌 → ETH = $1500
您的抵押率 = $15,000 / 5000 = 300%（仍安全，但有风险）

解决方案：
1. Deposit → 再存 5 WETH
2. 您的抵押率升至 500%（安全）
```

#### 场景 3：价格回升，我想套现部分 WETH

```
价格上升 → ETH = $2500
您现在有：15 WETH × $2500 = $37,500（原本 $20,000）

解决方案：
1. Withdraw → 取出 5 WETH
2. 保证抵押率 > 150%
3. 即可套现获利
```

#### 场景 4：我遭遇清算了，怎么办？

```
如果您的 Vault 被清算：
1. 清液人会偿还您部分债务
2. 您会失去一部分抵押物（清液奖励）
3. 您剩余的 Vault 会恢复到 170% 抵押率
4. 您可以继续操作这个 Vault

⚠️ 预防最好：
- 定期监控抵押率
- 保持 > 200% 的缓冲
- 市场波动时及时补充抵押
```

---

## 常见问题

### Q1: 稳定费是什么？为什么要支付？

**A**: 稳定费是协议的运营成本，年化 4%。每次还款时，您会支付：
```
稳定费 = 债务金额 × 4% × (天数 / 365)
```

例：欠 10,000 STB，30 天后还款：
```
稳定费 = 10,000 × 0.04 × (30/365) ≈ 32.88 STB
```

### Q2: 最高能铸造多少 STB？

**A**: 受最小抵押率限制：
```
最大铸造 = 抵押 WETH 价值（美元） × (100% / 150%)
```

例：存 10 WETH（价值 $20,000）：
```
最多铸造 = $20,000 / 1.5 = 13,333 STB
```

### Q3: 清液人如何获利？

**A**: 清液人获得清液奖励（8%）：
```
清液奖励 = 偿还的债务 × 8%（以抵押物形式）
```

例：清液人偿还 5,000 STB 债务：
```
获得的 WETH = 5,000 × $1 / $2000 × 1.08 ≈ 2.7 WETH
```

### Q4: 预言机断路器如何工作？

**A**: 当现货价格与 TWAP 偏差 > 20% 时：
- ❌ 禁止新的风险操作（存、取、铸、还）
- ✅ 保留清液功能（防止坏账）
- ⏳ 待价格恢复正常后自动恢复

### Q5: 我想成为 Keeper（清液机器人）需要什么？

**A**: 
1. 部署时指定为 `KEEPER_ADDRESS`
2. 拥有足够的 STB 进行清液
3. 后端会自动：
   - 扫描危险 Vault
   - 执行清液交易
   - 收集清液奖励

---

## 架构概览

### 系统三层架构

```
┌─────────────────────────────────────────┐
│        前端应用 (React + Vite)           │
│   - 钱包连接 (Wagmi)                     │
│   - 实时数据展示                        │
│   - 用户交互界面                        │
└────────────────┬────────────────────────┘
                 │ REST API
┌────────────────▼────────────────────────┐
│    后端服务 (Node + Express)             │
│  ┌──────────────────────────────────┐  │
│  │ 4 个 Worker 模块：                │  │
│  │ • Indexer  - 事件索引和状态跟踪  │  │
│  │ • Keeper   - 自动清液机器人      │  │
│  │ • TWAP     - 价格计算和更新      │  │
│  │ • Server   - REST API 服务       │  │
│  └──────────────────────────────────┘  │
│  数据库: SQLite + Prisma                │
└────────────────┬────────────────────────┘
                 │ Web3 RPC
┌────────────────▼────────────────────────┐
│    智能合约 (Solidity on Sepolia)       │
│  ┌──────────────────────────────────┐  │
│  │ • StableVault    - 核心金库合约  │  │
│  │ • STBToken       - 稳定币 ERC20  │  │
│  │ • OracleHub      - 预言机中心    │  │
│  │ • TwapOracle     - TWAP 价格更新 │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### 数据流向

```
链上事件 → Indexer 监听 → 解析事件 → 更新数据库 → API 查询 → 前端显示
          ↓
        Keeper 扫描危险 Vault → 执行清液 → 发出交易 → 链上执行 → 状态更新

Chainlink 价格 → TWAP Worker 采样 → 计算平均价格 → 更新 TwapOracle → 
  OracleHub 验证 → API 返回价格状态 → 前端显示
```

---

## 🚀 高级配置

### 调整 Keeper 参数

编辑 `backend/.env`：

```env
# Keeper 最大重试次数（默认 2）
KEEPER_MAX_ATTEMPTS=3

# 重试退避时间（毫秒，默认 500）
KEEPER_BACKOFF_MS=1000

# 每次扫描最多处理 Vault 数（默认 100）
KEEPER_BATCH_SIZE=50
```

### 调整 TWAP 参数

编辑 `backend/.env`：

```env
# TWAP 时间窗口（秒，默认 3600 = 1 小时）
TWAP_WINDOW_SECONDS=7200

# 样本限制（默认 100）
TWAP_SAMPLE_LIMIT=200
```

---

## 📞 技术支持

### 常见错误排查

| 错误 | 原因 | 解决方案 |
|------|------|--------|
| `RPC connection failed` | RPC 地址错误 | 检查 `.env` 中的 RPC_URL |
| `Contract not deployed` | 地址错误 | 重新部署并更新 `.env` |
| `Insufficient balance` | gas 不足 | 充值 Sepolia ETH |
| `Oracle breaker triggered` | 价格异常 | 等待价格恢复 |

### 获取帮助

- 📖 查看合约代码：`contracts/src/`
- 🔍 查看后端逻辑：`backend/src/`
- 🎨 查看前端代码：`frontend/src/`
- 📝 查看日志：后端控制台输出

---

## 📄 许可证

MIT License

---

**最后更新**：2026 年 2 月 11 日
