import type { Address } from 'viem'

const asAddress = (value: string | undefined): Address | undefined => {
  if (!value) return undefined
  return /^0x[a-fA-F0-9]{40}$/.test(value) ? (value as Address) : undefined
}

export const CONTRACTS = {
  vaultManager: asAddress(import.meta.env.VITE_VAULT_MANAGER_ADDRESS),
  stabilityEngine: asAddress(import.meta.env.VITE_STABILITY_ENGINE_ADDRESS),
  stablecoin: asAddress(import.meta.env.VITE_STABLECOIN_ADDRESS),
  oracle: asAddress(import.meta.env.VITE_ORACLE_ADDRESS),
}

export const contractsReady = Boolean(
  CONTRACTS.vaultManager &&
  CONTRACTS.stabilityEngine &&
  CONTRACTS.stablecoin &&
  CONTRACTS.oracle,
)

export const VAULT_MANAGER_ABI = [
  {
    type: 'function',
    name: 'open_vault',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    type: 'function',
    name: 'deposit_collateral',
    stateMutability: 'payable',
    inputs: [],
    outputs: [],
  },
  {
    type: 'function',
    name: 'get_vault',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'collateral', type: 'uint256' },
          { name: 'debt', type: 'uint256' },
          { name: 'exists', type: 'bool' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'collateral_ratio',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const

export const STABILITY_ENGINE_ABI = [
  {
    type: 'function',
    name: 'mcr',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'mint',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount_out', type: 'uint256' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'repay',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount_in', type: 'uint256' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'withdraw_collateral',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
] as const

export const STABLECOIN_ABI = [
  {
    type: 'function',
    name: 'approve',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const

export const ORACLE_ABI = [
  {
    type: 'function',
    name: 'get_price',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const
