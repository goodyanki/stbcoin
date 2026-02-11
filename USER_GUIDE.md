# StableVault User Guide

## Project Overview

StableVault is an over-collateralized stablecoin protocol MVP deployed on the Sepolia testnet. Users can deposit WETH as collateral to mint STB stablecoins. The protocol includes automated liquidation mechanisms, dual oracle verification with Chainlink spot prices and TWAP prices, a REST API for real-time data, and a web-based user interface.

## System Requirements

To run StableVault, you need Node.js version 20 or higher, npm for package management, Foundry for smart contract compilation and deployment, and Git for version control.

To check if Node.js is installed, run `node --version` and `npm --version`. Check Foundry with `forge --version`. If Foundry is not installed, use this command:

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

You will also need access to a Sepolia testnet RPC node. Popular options include Alchemy and Infura.

## Quick Start

First, clone the repository:

```
git clone https://github.com/goodyanki/stbcoin.git
cd stbcoin
```

To deploy smart contracts, go to the contracts directory and copy the environment file:

```
cd contracts
cp .env.example .env
```

Edit the .env file with your private key for the Sepolia account, RPC URL, Chainlink ETH/USD aggregator address (0x694AA1769357215DE4FAC081bf1f309adC325306), and WETH address (0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9). Then deploy:

```
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

Save the deployed contract addresses from the output, as you will need them for the backend and frontend configuration.

To start the backend service, navigate to the backend directory:

```
cd ../backend
cp .env.example .env
```

In the .env file, add the contract addresses from the deployment step above: STABLE_VAULT_ADDRESS, STB_TOKEN_ADDRESS, ORACLE_HUB_ADDRESS, and TWAP_ORACLE_ADDRESS. Also set your RPC_URL and optionally KEEPER_ADDRESS for the liquidation bot.

Then install dependencies, initialize the database, and start the service:

```
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run dev
```

The backend should now be running on http://localhost:3000. You should see messages indicating that the indexer, keeper, TWAP worker, and API server have started.

To start the frontend, go to the frontend directory:

```
cd ../frontend
cp .env.example .env
```

Edit .env with the contract address, RPC URL, and chain ID (11155111 for Sepolia):

```
npm install
npm run dev
```

Access the frontend at http://localhost:5173. You can verify the backend is working by checking http://localhost:3000/health, which should return an OK response.

## Core Features

Depositing WETH and minting STB is the primary use case. You start by connecting your wallet to the Sepolia testnet. Then you select "Deposit" in the action panel and enter the amount of WETH you want to deposit as collateral. After confirming the transaction, your collateral is locked in the vault. Next, you can switch to the "Mint" section and enter the amount of STB you want to create. The amount is limited by your collateral ratio, which must stay above 150 percent.

Your collateral ratio is calculated as the dollar value of your WETH collateral divided by your STB debt. A 150 percent ratio means your collateral is worth 1.5 times your debt. A ratio above 170 percent is considered safe, between 150 and 170 percent is a warning level, and below 150 percent is dangerous and can trigger liquidation.

To repay your debt and withdraw collateral, you use the "Repay" and "Withdraw" actions. When you repay, you pay back STB tokens along with a stability fee, which is 4 percent annually. You cannot withdraw all your collateral until your debt is zero, and any withdrawal must maintain your ratio above 150 percent.

The dashboard displays your vault information including collateral amount, debt amount, and collateral ratio. It also shows protocol-wide metrics like total collateral, total STB supply, average collateral ratio, and the status of the oracle system including Chainlink spot prices and TWAP prices.

## How Liquidation Works

If your vault falls below 150 percent collateral ratio, it becomes eligible for liquidation. The liquidation process is automated through keeper bots that constantly monitor vault health. When a keeper finds an unhealthy vault, it can execute a liquidation transaction that partially pays off the debt and seizes some of your collateral as a reward. The liquidator receives an 8 percent bonus on the collateral they seize.

After liquidation, your vault is adjusted so that the ratio recovers to approximately 170 percent, allowing you to continue using the vault or paying back remaining debt.

## Protection Mechanisms

The protocol includes an oracle circuit breaker to prevent operations during price anomalies. If the spot price from Chainlink deviates from the TWAP price by more than 20 percent, the system blocks new risky operations like depositing, minting, and withdrawing. Liquidations are still allowed during this period to prevent bad debt accumulation. Normal operations resume automatically once prices stabilize.

## Using the Application

To create a vault, select "Deposit" and enter 10 WETH. After confirmation, you have 10 WETH as collateral worth approximately 20,000 dollars at a 2,000 dollar ETH price. Then select "Mint" and enter 5,000 STB. Your new collateral ratio is 400 percent, which is very safe.

If the market drops and ETH falls to 1,500 dollars, your ratio drops to 300 percent. You can add more collateral by depositing additional WETH to increase your safety margin. If the price rises to 2,500 dollars and you want to take profits, you can withdraw excess WETH as long as your ratio stays above 150 percent.

If your vault is liquidated, the liquidator covers part of your debt and takes some collateral. Your remaining vault adjusts to a 170 percent ratio. You can continue using the vault or repay the remaining debt. To avoid liquidation, monitor your ratio regularly and maintain a buffer above 200 percent.

