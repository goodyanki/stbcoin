import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('wagmi/chains', () => ({
  foundry: { id: 31337 },
  sepolia: { id: 11155111 },
}))

vi.mock('wagmi/connectors', () => ({
  injected: vi.fn(() => ({ connector: 'injected' })),
}))

vi.mock('wagmi', () => ({
  http: vi.fn((url?: string) => ({ url })),
  createConfig: vi.fn((value: unknown) => value),
}))

describe('src/wagmi.ts', () => {
  beforeEach(() => {
    vi.resetModules()
    vi.unstubAllEnvs()
  })

  it('defaults to foundry chain', async () => {
    vi.stubEnv('VITE_TARGET_CHAIN_ID', '')
    const mod = await import('./wagmi')
    expect(mod.targetChain.id).toBe(31337)
    expect(mod.targetChainId).toBe(31337)
    expect(mod.config.chains.some((c) => c.id === 31337)).toBe(true)
  })

  it('switches to sepolia when env target id is 11155111', async () => {
    vi.stubEnv('VITE_TARGET_CHAIN_ID', '11155111')
    const mod = await import('./wagmi')
    expect(mod.targetChain.id).toBe(11155111)
    expect(mod.targetChainId).toBe(11155111)
  })
})
