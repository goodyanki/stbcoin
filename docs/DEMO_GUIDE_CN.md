# StableVault 本地演示指南（中文）

本文档给出一条稳定、可复现的本地演示路径，重点验证：
- 存入抵押并铸造 STB
- 手动下调价格触发风险
- keeper 自动清算并落库

## 1. 一键启动（推荐）

在仓库根目录执行：

```bash
./scripts/dev_bootstrap.sh
```

脚本会自动完成：
- 启动/复用本地 `anvil`
- 部署合约
- 写入 `backend/.env` 与 `frontend/.env(.local)`
- 设置 keeper/demo mode/start block 等关键参数

> 注意：保持该终端窗口运行，不要关闭 `anvil` 进程。

## 2. 启动后端与前端

后端：

```bash
cd backend
npm run dev
```

前端：

```bash
cd frontend
npm run dev
```

访问：`http://127.0.0.1:5173`

## 3. 演示流程

1. 钱包连接本地链 `31337`。  
2. 存入抵押（例如 10 ETH）。  
3. 铸造 STB（例如 5000 STB）。  
4. 管理员下调 demo 价格（例如 ETH=700）。  
5. 等待 keeper tick（通常 15~30 秒内）。  
6. 观察仓位健康状态变化与清算结果。

## 4. 关键认知（避免误判）

- 下调 ETH 价格会先降低抵押率（CR/Health）。
- `debt` 数值不会因为“降价”直接变化。
- `debt` 只有在 `repay` 或 `liquidate` 发生后才会变化。

因此，若你看到价格已下降但 debt 不变，先检查是否真的发生了清算事件。

## 5. 后端诊断接口

优先检查以下接口：

- `GET /v1/keeper/status`
  - 看 `lastErrorClass`、`lastErrorMessage`、`autoFundLastResult`、`ownersScannedOnChain`
- `GET /v1/liquidations?limit=20`
  - 确认是否有新的清算记录
- `GET /v1/vaults/:owner`
  - 对比链上仓位快照是否更新

## 6. 常见故障定位

- keeper 不动作：
  - 检查 `backend/.env` 的 `KEEPER_PRIVATE_KEY` 是否与部署 `setKeeper` 地址一致
  - 检查 `START_BLOCK` 是否正确（由 bootstrap 自动写入）
  - 检查 `KEEPER_AUTO_FUND_ENABLED`（本地建议 `true`）
- 有报错但无清算：
  - 看 `/v1/keeper/status` 的 `lastErrorClass` 与 `lastErrorMessage`
  - 看后端日志中是否出现 revert / rpc 错误

