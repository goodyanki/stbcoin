# Architecture Documentation: System Design and Component Interaction

## System Overview

StableVault is a three-tier distributed system consisting of smart contracts on Sepolia blockchain, a Node.js backend service, and a React frontend application. The system enables users to deposit collateral, mint stablecoins, manage positions, and handles automated liquidations through keeper bots.



## Component Details

### Frontend Layer

The frontend is built with React and Vite, providing a user interface for interacting with the protocol. The Header component handles wallet connection using Wagmi, which integrates with MetaMask and other Web3 wallets. The Dashboard displays real-time information about the user's vault including collateral amount, debt, and collateral ratio. The ActionPanel provides input forms for deposit, mint, repay, and withdraw operations. The ContractContext uses React Context to manage global state and handle all smart contract interactions through ethers.js or viem.

### Backend Layer

The backend is a Node.js service using Express that manages four main workers and a REST API server.

The REST API Server exposes endpoints at /health, /v1/protocol/metrics, /v1/oracle/status, /v1/vaults/:owner, /v1/vaults?health=danger, /v1/liquidations, and /v1/keeper/status. These endpoints allow the frontend and external systems to query vault states, oracle prices, protocol metrics, and liquidation history.

The Indexer Worker listens to blockchain events including Deposited, Withdrawn, Minted, Repaid, and Liquidated events. It extracts vault owner information from these events and updates the vault_state table in the database. It also maintains a history of liquidation events in the liquidation_event table.

The Keeper Worker periodically scans the vault_state table for vaults with health status of "danger" or "warning". For each at-risk vault, it attempts to execute a liquidate() transaction on the StableVault contract. It implements retry logic with exponential backoff to handle transaction failures. The status of keeper operations is tracked in the keeper_status table.

The TWAP Worker runs at regular intervals to calculate time-weighted average prices. It samples the current Chainlink ETH/USD price, stores it in the oracle_sample table, and calculates the average of recent samples within the configured time window. It then calls updateTwap() on the TwapOracle contract to update the on-chain TWAP price.

The SQLite Database stores all state using Prisma ORM. It includes tables for vault_state, liquidation_event, oracle_sample, and keeper_status.

### Smart Contracts Layer

StableVault.sol is the core contract managing vault creation, deposits, minting, repayment, and liquidation. It stores vault information in a mapping from owner address to Vault struct. It maintains protocol parameters like minimum collateral ratio (150%), stability fee (4% annually), and liquidation bonus (8%). It calls OracleHub to verify prices before executing risky operations.

STBToken.sol is an ERC20 token representing the stablecoin. Only StableVault can mint and burn tokens. Users can transfer and approve STB for spending.

OracleHub.sol verifies prices using both Chainlink aggregators and the TWAP oracle. It implements a circuit breaker that disables risky operations when prices deviate by more than 20% between spot and TWAP prices. It returns the effective price for liquidation calculations.

TwapOracle.sol stores the most recent TWAP price updated by the backend TWAP Worker. It maintains the timestamp of the last update to detect stale prices.







