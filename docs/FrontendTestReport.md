1.Test report
run npm run test
nick@yanqi:~/stbcoin/frontend$ npm run test

> frontend@0.0.0 test
> vitest run


 RUN  v2.1.9 /home/nick/stbcoin/frontend

stderr | src/components/ActionPanel.test.tsx > ActionPanel > disables action when wallet disconnected
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > submits deposit action and shows success feedback
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > submits deposit action and shows success feedback
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > submits deposit action and shows success feedback
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/Dashboard.test.tsx > Dashboard > renders core protocol metrics
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/Dashboard.test.tsx > Dashboard > shows liquidation guidance and distance
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/LiquidationDemo.test.tsx > LiquidationDemo > shows read-only text for non-owner
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/LiquidationDemo.test.tsx > LiquidationDemo > owner can apply demo price
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/LiquidationDemo.test.tsx > LiquidationDemo > owner can apply demo price
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

 ✓ src/App.test.tsx (1)
 ✓ src/components/ActionPanel.test.tsx (3) 1044ms
 ✓ src/components/ConnectWallet.test.tsx (3) 332ms
 ✓ src/components/Dashboard.test.tsx (2) 346ms
 ✓ src/components/LiquidationDemo.test.tsx (2) 502ms
 ✓ src/context/ContractContext.test.tsx (2)

 Test Files  6 passed (6)
      Tests  13 passed (13)
   Start at  19:44:47
   Duration  2.70s (transform 289ms, setup 477ms, collect 6.93s, tests 2.50s, environment 2.13s, prepare 421ms)


2. Coverage test result
run npm run test:coverage


> frontend@0.0.0 test:coverage
> vitest run --coverage


 RUN  v2.1.9 /home/nick/stbcoin/frontend
      Coverage enabled with v8

stderr | src/components/ActionPanel.test.tsx > ActionPanel > disables action when wallet disconnected
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > submits deposit action and shows success feedback
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > submits deposit action and shows success feedback
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/Dashboard.test.tsx > Dashboard > renders core protocol metrics
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/Dashboard.test.tsx > Dashboard > shows liquidation guidance and distance
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Statistic] `valueStyle` is deprecated. Please use `styles.content` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > submits deposit action and shows success feedback
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/LiquidationDemo.test.tsx > LiquidationDemo > shows read-only text for non-owner
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/LiquidationDemo.test.tsx > LiquidationDemo > owner can apply demo price
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/LiquidationDemo.test.tsx > LiquidationDemo > owner can apply demo price
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.
Warning: [antd: Alert] `message` is deprecated. Please use `title` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

stderr | src/components/ActionPanel.test.tsx > ActionPanel > shows projected CR on mint tab
Warning: [antd: Card] `bordered` is deprecated. Please use `variant` instead.

 ✓ src/App.test.tsx (1)
 ✓ src/contracts.test.ts (2)
 ✓ src/main.test.tsx (1) 1846ms
 ✓ src/wagmi.test.ts (2) 720ms
 ✓ src/components/ActionPanel.test.tsx (3) 1603ms
 ✓ src/components/ConnectWallet.test.tsx (3) 469ms
 ✓ src/components/Dashboard.test.tsx (2) 479ms
 ✓ src/components/Header.test.tsx (1)
 ✓ src/components/LiquidationDemo.test.tsx (2) 730ms
 ✓ src/config/contracts.test.ts (2)
 ✓ src/context/ContractContext.test.tsx (2)

 Test Files  11 passed (11)
      Tests  21 passed (21)
   Start at  19:49:00
   Duration  4.22s (transform 716ms, setup 997ms, collect 12.91s, tests 6.66s, environment 6.51s, prepare 977ms)

 % Coverage report from v8
----------------------|---------|----------|---------|---------|---------------------------------------------------------
File                  | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s                                       
----------------------|---------|----------|---------|---------|---------------------------------------------------------
All files             |   90.22 |    58.33 |   85.18 |   90.22 |                                                         
 src                  |     100 |     92.3 |     100 |     100 |                                                         
  App.tsx             |     100 |      100 |     100 |     100 |                                                         
  contracts.ts        |     100 |      100 |     100 |     100 |                                                         
  main.tsx            |     100 |      100 |     100 |     100 |                                                         
  wagmi.ts            |     100 |       75 |     100 |     100 | 12                                                      
 src/components       |   96.83 |    60.52 |   81.81 |   96.83 |                                                         
  ActionPanel.tsx     |   95.76 |    62.16 |   83.33 |   95.76 | 55-56,74-76,123                                         
  ConnectWallet.tsx   |     100 |     90.9 |   83.33 |     100 | 26                                                      
  Dashboard.tsx       |    98.3 |    23.07 |     100 |    98.3 | 68-69                                                   
  Header.tsx          |     100 |      100 |     100 |     100 |                                                         
  LiquidationDemo.tsx |   92.85 |    64.28 |   66.66 |   92.85 | 18-20,29,88-89                                          
 src/config           |     100 |        0 |     100 |     100 |                                                         
  contracts.ts        |     100 |        0 |     100 |     100 | 5                                                       
 src/context          |    67.6 |       40 |     100 |    67.6 |                                                         
  ContractContext.tsx |    67.6 |       40 |     100 |    67.6 | ...-196,199-208,211-220,235-245,252-264,268-280,290-292 
----------------------|---------|----------|---------|---------|---------------------------------------------------------
