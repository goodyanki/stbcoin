import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('src/contracts.ts', () => {
  beforeEach(() => {
    vi.resetModules()
    vi.unstubAllEnvs()
  })

  it('maps valid addresses and marks contracts ready', async () => {
    vi.stubEnv('VITE_VAULT_MANAGER_ADDRESS', '0x1111111111111111111111111111111111111111')
    vi.stubEnv('VITE_STABILITY_ENGINE_ADDRESS', '0x2222222222222222222222222222222222222222')
    vi.stubEnv('VITE_STABLECOIN_ADDRESS', '0x3333333333333333333333333333333333333333')
    vi.stubEnv('VITE_ORACLE_ADDRESS', '0x4444444444444444444444444444444444444444')

    const mod = await import('./contracts')
    expect(mod.CONTRACTS.vaultManager).toBe('0x1111111111111111111111111111111111111111')
    expect(mod.CONTRACTS.stabilityEngine).toBe('0x2222222222222222222222222222222222222222')
    expect(mod.CONTRACTS.stablecoin).toBe('0x3333333333333333333333333333333333333333')
    expect(mod.CONTRACTS.oracle).toBe('0x4444444444444444444444444444444444444444')
    expect(mod.contractsReady).toBe(true)
  })

  it('rejects invalid addresses and marks not ready', async () => {
    vi.stubEnv('VITE_VAULT_MANAGER_ADDRESS', 'invalid')
    vi.stubEnv('VITE_STABILITY_ENGINE_ADDRESS', '0x2222222222222222222222222222222222222222')
    vi.stubEnv('VITE_STABLECOIN_ADDRESS', '')
    vi.stubEnv('VITE_ORACLE_ADDRESS', '0x4444444444444444444444444444444444444444')

    const mod = await import('./contracts')
    expect(mod.CONTRACTS.vaultManager).toBeUndefined()
    expect(mod.CONTRACTS.stablecoin).toBeUndefined()
    expect(mod.contractsReady).toBe(false)
    expect(mod.VAULT_MANAGER_ABI.length).toBeGreaterThan(0)
    expect(mod.STABILITY_ENGINE_ABI.length).toBeGreaterThan(0)
    expect(mod.STABLECOIN_ABI.length).toBeGreaterThan(0)
    expect(mod.ORACLE_ABI.length).toBeGreaterThan(0)
  })
})
