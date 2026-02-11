# StableVault Architecture (Stablecoin-Centric)

## 1. Design Focus
The architecture is centered on the on-chain stablecoin system:
- `StableVault` is the core risk engine.
- `STBToken` is the mint/burn asset.
- `OracleHub` + `TwapOracle` provide price validity and breaker control.

Frontend and backend are supporting layers, not the trust core.

## 2. Mermaid Architecture Diagram
```mermaid
flowchart TB
    U[User Wallet] --> F[Frontend UI]
    F -->|write tx / read state| SV[StableVault]

    subgraph On-chain Stablecoin Core
      SV -->|mint/burn authority| STB[STBToken]
      SV -->|risk checks| OH[OracleHub]
      OH -->|TWAP read| TO[TwapOracle]
      OH -->|spot price read| CL[Chainlink ETH/USD]
    end

    B[Backend API + Keeper + Indexer] -->|set demo/twap, liquidation bot, event indexing| SV
    B -->|publish TWAP samples| TO
    F -->|health/metrics/vault queries| B

    style SV fill:#1f2937,color:#fff,stroke:#111827,stroke-width:2px
    style STB fill:#1e3a8a,color:#fff,stroke:#1e40af
    style OH fill:#0f766e,color:#fff,stroke:#115e59
    style TO fill:#6d28d9,color:#fff,stroke:#5b21b6
```

## 3. Contract Responsibilities

### StableVault (Core)
- Maintains vault state: collateral, debt principal, accrued fee.
- Handles user actions: `deposit`, `withdraw`, `mint`, `repay`.
- Executes `liquidate` for unhealthy vaults.
- Tracks protocol reserve and `systemBadDebt`.
- Enforces controls: pause, keeper permissions, risk parameters.

### STBToken
- ERC20-compatible stablecoin.
- Only `StableVault` can `mint` and `burn`.
- Standard transfer/approve/allowance for user and keeper flows.

### OracleHub
- Combines spot + TWAP into validated risk price.
- Breaker triggers on stale/deviated oracle data.
- Supports owner-controlled demo mode for deterministic testing.

### TwapOracle
- Stores latest published TWAP price and timestamp.
- Accepts updates only from owner/authorized publisher.

## 4. Key Design Decisions and Trade-offs
- **Single core vault contract**:
  - simpler integration and audit path
  - trade-off: large core contract surface
- **Oracle breaker before risky actions**:
  - protects against bad pricing during mint/withdraw/liquidate windows
  - trade-off: temporary user operation blocking during anomalies
- **Keeper-based liquidation**:
  - automates unhealthy vault cleanup
  - trade-off: backend operator availability matters for automation quality
- **Demo mode in OracleHub**:
  - enables reliable demo/testing of liquidation and bad debt scenarios
  - trade-off: strictly admin-controlled to avoid production misuse






