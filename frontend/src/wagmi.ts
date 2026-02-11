import { http, createConfig } from 'wagmi'
import { foundry, sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

export const targetChainId = Number(import.meta.env.VITE_TARGET_CHAIN_ID || foundry.id)
export const targetChain = targetChainId === sepolia.id ? sepolia : foundry

export const config = createConfig({
  chains: [foundry, sepolia],
  connectors: [injected()],
  transports: {
    [foundry.id]: http(import.meta.env.VITE_RPC_URL || 'http://127.0.0.1:8545'),
    [sepolia.id]: http(import.meta.env.VITE_SEPOLIA_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com'),
  },
})
