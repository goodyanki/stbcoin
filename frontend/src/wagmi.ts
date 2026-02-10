import { http, createConfig } from 'wagmi'
import { foundry } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

export const config = createConfig({
  chains: [foundry],
  connectors: [injected()],
  transports: {
    [foundry.id]: http(import.meta.env.VITE_RPC_URL || 'http://127.0.0.1:8545'),
  },
})
