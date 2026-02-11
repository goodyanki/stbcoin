export const CONTRACTS = {
  stableVault: import.meta.env.VITE_STABLE_VAULT_ADDRESS as `0x${string}` | undefined,
  oracleHub: import.meta.env.VITE_ORACLE_HUB_ADDRESS as `0x${string}` | undefined,
  stbToken: import.meta.env.VITE_STB_TOKEN_ADDRESS as `0x${string}` | undefined,
  backendBaseUrl: (import.meta.env.VITE_BACKEND_URL as string | undefined) ?? "http://localhost:8080"
}

export const STABLE_VAULT_ABI = [
  {
    type: 'function',
    name: 'deposit',
    stateMutability: 'payable',
    inputs: [{ name: 'ethAmount', type: 'uint256' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'withdraw',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'ethAmount', type: 'uint256' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'mint',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'stbAmount', type: 'uint256' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'repay',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'stbAmount', type: 'uint256' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'liquidate',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'ownerAddress', type: 'address' }, { name: 'repayAmount', type: 'uint256' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'getVault',
    stateMutability: 'view',
    inputs: [{ name: 'ownerAddress', type: 'address' }],
    outputs: [
      { name: 'collateralAmount', type: 'uint256' },
      { name: 'debtPrincipal', type: 'uint256' },
      { name: 'accruedFee', type: 'uint256' },
      { name: 'debtWithFee', type: 'uint256' },
      { name: 'lastAccruedTimestamp', type: 'uint256' },
      { name: 'lastRiskActionBlock', type: 'uint256' }
    ]
  },
  {
    type: 'function',
    name: 'getCollateralRatioBps',
    stateMutability: 'view',
    inputs: [{ name: 'ownerAddress', type: 'address' }],
    outputs: [{ name: 'ratioBps', type: 'uint256' }]
  },
  {
    type: 'function',
    name: 'isLiquidatable',
    stateMutability: 'view',
    inputs: [{ name: 'ownerAddress', type: 'address' }],
    outputs: [{ name: 'liquidatable', type: 'bool' }]
  },
  {
    type: 'function',
    name: 'setDemoMode',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'enabled', type: 'bool' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'setDemoPrice',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'priceE18', type: 'uint256' }],
    outputs: []
  },
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: 'ownerAddress', type: 'address' }]
  }
] as const

export const ERC20_ABI = [
  {
    type: 'function',
    name: 'approve',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'spender', type: 'address' }, { name: 'value', type: 'uint256' }],
    outputs: [{ name: 'ok', type: 'bool' }]
  },
  {
    type: 'function',
    name: 'allowance',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }],
    outputs: [{ name: 'allowance', type: 'uint256' }]
  }
] as const

export const ORACLE_HUB_ABI = [
  {
    type: 'function',
    name: 'getPriceStatus',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'effectivePrice', type: 'uint256' },
      { name: 'spotPrice', type: 'uint256' },
      { name: 'twapPrice', type: 'uint256' },
      { name: 'spotUpdatedAt', type: 'uint256' },
      { name: 'twapUpdatedAt', type: 'uint256' },
      { name: 'breakerTriggered', type: 'bool' }
    ]
  }
] as const
