# Presentation Script: StableVault (5 Minutes)
# 演讲稿：StableVault (5分钟)

**Speaker**: Development Team / 开发团队
**Project**: StableVault (STB) / 项目：StableVault (STB)

---

## 1. Introduction (1 min)
## 1. 项目介绍与背景 (1分钟)

**[Slide 1: Title Page - StableVault]**

**English:**
Hello everyone. The problem we are addressing is clear: while cryptocurrencies offer decentralized value transfer, their extreme price volatility limits their adoption for payments and savings.
To solve this, we built **StableVault (STB)**—a decentralized, over-collateralized stablecoin system on Ethereum.

**Chinese:**
大家好，我们需要解决的问题非常明确：虽然加密货币通过去中心化实现了价值自由流转，但其本身剧烈的价格波动限制了其作为支付手段和价值存储的普及。
为了解决这个问题，我们开发了 **StableVault (STB)**。这是一个基于以太坊的去中心化、超额抵押稳定币系统。

**English:**
The core mechanism is simple: users deposit volatile assets like ETH into a smart contract as collateral to mint STB, a stablecoin pegged to 1 Dollar. Through over-collateralization and automated liquidation, we ensure that every STB is always backed by more than $1 of value.

**Chinese:**
核心机制很简单：用户将波动性资产（如 ETH）存入智能合约作为抵押，然后按一定比例铸造出价值锚定 1 美元的稳定币 STB。通过超额抵押（Over-collateralization）和清算机制，确保每个 STB 背后始终有超过 1 美元的资产支持。

**English:**
Our team roles are:
- [Member A]: Smart Contract Logic & Security.
- [Member B]: Backend Keeper Bots & Oracle Services.
- [Member C]: Frontend Interaction & User Experience.

**Chinese:**
我们的团队分工如下：
- [成员A] 负责智能合约核心逻辑与安全性。
- [成员B] 负责后端清算机器人 (Keeper) 与价格预言机。
- [成员C] 负责前端交互与用户体验设计。

---

## 2. Technical Architecture (1 min)
## 2. 技术架构 (1分钟)

**[Slide 2: System Architecture Diagram]**

**English:**
Please look at our architecture diagram. StableVault consists of three core layers:
1.  **Smart Contracts**: Deployed on Sepolia, handling Vault management, STB tokens, and the OracleHub.
2.  **Backend Services**: 
    - An **Indexer** that listens to chain events to update the database.
    - **Keeper Bots**: Our guardians that monitor vault health and trigger liquidations automatically if collateral ratios drop too low.
    - **TWAP Oracle**: Calculates time-weighted average prices to prevent flash crashes.
3.  **Frontend**: A React-based dashboard for real-time asset management.

**Chinese:**
请看这张架构图，StableVault 由三个核心层组成：
1.  **智能合约层**：部署在 Sepolia 测试网。这是系统的核心，包含 Vault 管理、STB 代币逻辑和 OracleHub。
2.  **后端服务层**：
    - **Indexer**：实时监听链上事件，更新数据库状态。
    - **Keeper Bots**：这是我们的守护者，自动监控所有 Vault 的健康度，一旦抵押率过低，立即触发清算，保护系统偿付能力。
    - **TWAP Oracle**：计算时间加权平均价格，防止价格瞬间操纵。
3.  **前端应用层**：基于 React 和 Vite，为用户提供直观的仪表盘，实时展示资产状况。

**English:**
**Key Design Decision**: We implemented a **"Dual-Oracle Mechanism"**. The system reads both Chainlink spot prices and our own TWAP. Minting or liquidating is only allowed if the deviation between them is safe (e.g., within 10%). This defends against flash loan attacks and price manipulation.

**Chinese:**
**关键设计决策**：我们采用了 **"双预言机机制" (Dual-Oracle Mechanism)**。系统同时读取 Chainlink 的现货价格和我们自建的 TWAP 价格。只有当两者偏差在安全范围内（例如 10% 以内）时，才允许铸造或清算。这极大提高了系统对于闪电贷攻击和价格操纵的防御能力。

---

## 3. Live Demonstration (1 min)
## 3. 现场演示 (1分钟)

**[Slide 3: Browser Demo]**

**English:**
Let's see the system in action.
*(Open Frontend)*

**Chinese:**
现在让我们看看系统的实际运行。
*(打开前端页面)*

**English:**
1.  **Connect & Dashboard**: I connect my wallet. The dashboard clearly shows my Collateral, Debt, and Health Factor.
2.  **Deposit & Mint**: I deposit 10 ETH and mint 5000 STB. Once confirmed, my Health Factor remains "Safe" (Green), with a collateral ratio of around 500%.

**Chinese:**
1.  **连接钱包与仪表盘**：首先，我连接钱包。大家可以看到 Dashboard 清晰地显示了我当前的抵押品 ETH 数量、铸造的 STB 债务以及健康度（Health Factor）。
2.  **存入与铸造**：我现在存入 10 ETH，然后铸造 5000 STB。交易确认后，大家看到我的健康度依然是绿色的 "Safe"，抵押率在 500% 左右。

**English:**
3.  **Risk Simulation**: To demonstrate liquidation, we have a "Demo Mode". I simulate a sudden ETH price crash to $700.
    - My Vault status instantly turns to "Danger" (Red).
4.  **Auto-Liquidation**: The Keeper bot running in the backend detects this risk immediately.
    - *(Refresh Page)*
    - A "Liquidated" transaction appears. My debt is repaid by auctioning some collateral, restoring system health.

**Chinese:**
3.  **风险演示**：为了演示清算，我们内置了一个 "Demo Mode"。我现在模拟 ETH 价格瞬间暴跌到 $700。
    - 大家看，我的 Vault 状态瞬间变成了红色的 "Danger"。
4.  **自动清算**：哪怕我不做任何操作，后台的 Keeper 机器人已经检测到了这个风险。
    - *(刷新页面)*
    - 几秒钟后，我们可以看到一笔 "Liquidated" 交易已经发生。我的部分 ETH 被拍卖以偿还债务，系统坏账被消除，整体恢复健康。

这就是 StableVault 自动化风控的闭环。

---

## 4. Technical Deep Dive (1 min)
## 4. 技术深度解析 (1分钟)

**[Slide 4: Code Snippet - OracleHub.sol]**

**English:**
A major challenge was preventing oracle manipulation. We built a core component called `OracleHub`.
Look at this snippet:

**Chinese:**
在开发过程中，最有趣的挑战是如何防止预言机失效或被操纵。
我们设计了一个核心组件 `OracleHub.sol`。请看这段代码：

```solidity
function getPriceStatus() public view returns (...) {
    // Read Chainlink Spot
    (uint256 spotPrice, ) = _readChainlinkE18();
    // Read TWAP
    (uint256 twapPrice, ) = twapOracle.getTwap();

    // Calculate Deviation
    uint256 diff = spotPrice > twapPrice ? spotPrice - twapPrice : twapPrice - spotPrice;
    uint256 deviationBps = (diff * 10_000) / twapPrice;

    // Circuit Breaker
    if (deviationBps > maxDeviationBps) {
        return (..., true); // breakerTriggered = true
    }
    return (spotPrice, ..., false);
}
```

**English:**
**Optimization & Security**: We included a **Circuit Breaker**. If the deviation between Chainlink and TWAP exceeds 12%, the `breakerTriggered` flag halts all borrowing and liquidations. This "freezes" the protocol to prevent bad debt in case of an oracle attack—a critical safety feature for DeFi.

**Chinese:**
**Gas 优化与安全**：我们不仅仅是比较价格，还引入了 **Circuit Breaker (熔断器)**。
如果 Chainlink 价格和 TWAP 价格偏差超过 12%，`breakerTriggered` 会变为 `true`。此时，`StableVault` 合约会自动暂停所有借贷和清算操作。
这种设计确保了即使外部预言机被黑客攻击，我们的系统也会自动"冻结"止损，而不是被掏空资金库。

---

## 5. Results & Reflection (1 min)
## 5. 总结与反思 (1分钟)

**[Slide 5: Summary & Future Work]**

**English:**
**Results**: StableVault is running stably on the Sepolia testnet. Our Keeper bots successfully passed stress tests involving liquidations, and the OracleHub correctly identifies price anomalies.

**Chinese:**
**成果**：StableVault 目前已在 Sepolia 测试网稳定运行。我们的 Keeper 机器人成功执行了多次压力测试下的清算任务，OracleHub 也能准确识别异常价格波动。

**English:**
**Reflections**:
- **What worked**: The clean separation of concerns (Contract/Backend/Frontend) made development efficient and the UI very responsive.
- **Improvements**: Currently, we use a fixed Max Close Factor for liquidations. In the future, we plan to implement "Dutch Auctions" to optimize liquidation efficiency and reduce impact on user assets.
- **Key Learning**: "Never trust a single data source." The dual-oracle pattern is our most valuable takeaway.

**Chinese:**
**反思与改进**：
- **做得好的**：前后端分离架构非常清晰，Indexer 的存在让前端数据加载极快，用户体验流畅。
- **可以改进的**：目前我们的清算逻辑是一次性清算大约 50% 的债务（Max Close Factor）。未来我们会考虑引入"荷兰式拍卖"机制来优化清算效率，减少对用户资产的冲击。
- **主要学习**：在 DeFi 开发中，"永远不要相信单一数据源"。双预言机和熔断机制是我们学到的最宝贵的安全经验。

**English:**
Thank you! We are open to questions.

**Chinese:**
谢谢大家！欢迎提问。

---
