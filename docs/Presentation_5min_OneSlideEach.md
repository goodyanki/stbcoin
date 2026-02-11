# StableVault 5-Min Presentation (One Slide per Section)

## Slide 1 (1 min): Introduction
### Title
`StableVault: A Minimal Over-Collateralized Stablecoin Protocol`

### Put on slide
- **Problem**
  - Stablecoin systems need transparent collateral, predictable liquidation, and testable risk controls.
- **Solution**
  - ETH-collateralized vault + STB mint/repay/withdraw
  - Oracle validation (Chainlink spot + TWAP + breaker)
  - Keeper-based liquidation + bad debt accounting
  - Full stack: Contracts + Backend indexer/API + Frontend
- **Team Roles** (replace with real names)
  - `[Name A]`: Smart contracts
  - `[Name B]`: Backend/indexer/keeper
  - `[Name C]`: Frontend and integration/testing

### Say in speech
- One sentence for pain point.
- One sentence for architecture-level solution.
- One sentence for role split.

---

## Slide 2 (1 min): Technical Architecture
### Title
`System Architecture and Key Design Decisions`

### Put on slide
- **Diagram** (simple 4-box flow)
  - User Wallet -> Frontend (React/wagmi) -> Contracts (StableVault/STB/OracleHub/TwapOracle)
  - Backend (Express + Prisma + SQLite) reads chain + runs keeper
- **Smart Contract Structure**
  - `StableVault`: core vault logic, risk checks, liquidation, bad debt
  - `STBToken`: vault-authorized mint/burn token
  - `OracleHub`: spot+TWAP validation and breaker
  - `TwapOracle`: publisher-updated TWAP feed
- **Design Trade-offs**
  - Prioritized clarity/safety over maximal feature scope
  - Added demo mode for deterministic liquidation demos
  - Keeper automation in backend for operational simplicity

### Say in speech
- Walk left-to-right through data/transaction flow.
- Mention why oracle breaker + keeper were chosen.

---

## Slide 3 (1 min): Live Demonstration
### Title
`Live User Flow: Deposit -> Mint -> Price Shock -> Liquidation`

### Put on slide
- **Demo Steps**
  1. Connect wallet on local fork (31337) or Sepolia
  2. Deposit ETH collateral
  3. Mint STB
  4. Lower demo ETH price (owner mode)
  5. Trigger/observe liquidation
  6. Check protocol metrics (`Bad Debt`, reserve, vault health)
- **What to show on UI**
  - Collateral, Debt, CR, Health badge
  - Liquidation control panel (demo price slider)
  - Backend status and protocol metrics card
- **Optional testnet tx**
  - Show one confirmed tx hash (deposit/mint/liquidate)

### Say in speech
- Focus on one full lifecycle path, not every button.

---

## Slide 4 (1 min): Technical Deep Dive
### Title
`Deep Dive: Risk Control and Security Hardening`

### Put on slide
- **Challenge solved**
  - Prevent unsafe operations during unreliable oracle conditions.
- **Implementation highlights**
  - `OracleHub.getPriceStatus()` checks staleness + deviation.
  - `StableVault` blocks risky actions when breaker triggers.
  - `nonReentrant` + CEI ordering for sensitive functions.
  - Pause switch for critical operation control.
- **Snippet to show** (short)
  - `canRiskActionProceed()` check before mint/withdraw/liquidate
  - `nonReentrant` on mutation paths
- **Performance/Security note**
  - Gas tests + Slither analysis integrated into workflow.

### Say in speech
- Explain one attack/risk model and how your code prevents it.

---

## Slide 5 (1 min): Results & Reflection
### Title
`Results, Lessons, and Next Steps`

### Put on slide
- **What worked well**
  - End-to-end flow works across contracts/backend/frontend.
  - Automated tests: contract + frontend coverage workflow.
  - Clear demo path for liquidation and bad debt behavior.
- **What we would improve**
  - Higher branch coverage, especially frontend edge paths.
  - More automation for env/address propagation after deploy.
  - Stronger observability and multi-keeper robustness.
- **Key learnings**
  - Risk controls must be testable, not just implemented.
  - Full-stack protocol demos require tight env consistency.
  - Security tooling (tests + static analysis) should be continuous.

### Say in speech
- 1 sentence for outcomes, 1 sentence for limitations, 1 sentence for learning.

---

## Presenter Tips (Optional)
- Keep each slide to **3-5 bullets max**.
- Use **large visuals** (architecture diagram, UI screenshot, one code snippet).
- For 1-minute timing: ~110-130 spoken words per slide.
