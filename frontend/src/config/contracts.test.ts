import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('src/config/contracts.ts', () => {
  beforeEach(() => {
    vi.resetModules()
    vi.unstubAllEnvs()
  })

  it('uses default backend url when env is missing', async () => {
    vi.stubEnv('VITE_BACKEND_URL', undefined)
    const mod = await import('./contracts')

    expect(mod.CONTRACTS.backendBaseUrl).toBe('http://localhost:8080')
    expect(mod.STABLE_VAULT_ABI.length).toBeGreaterThan(0)
    expect(mod.ERC20_ABI.length).toBe(2)
    expect(mod.ORACLE_HUB_ABI[0].name).toBe('getPriceStatus')
  })

  it('reads contract addresses from env', async () => {
    vi.stubEnv('VITE_STABLE_VAULT_ADDRESS', '0x1111111111111111111111111111111111111111')
    vi.stubEnv('VITE_ORACLE_HUB_ADDRESS', '0x2222222222222222222222222222222222222222')
    vi.stubEnv('VITE_STB_TOKEN_ADDRESS', '0x3333333333333333333333333333333333333333')
    vi.stubEnv('VITE_BACKEND_URL', 'http://127.0.0.1:9999')

    const mod = await import('./contracts')
    expect(mod.CONTRACTS.stableVault).toBe('0x1111111111111111111111111111111111111111')
    expect(mod.CONTRACTS.oracleHub).toBe('0x2222222222222222222222222222222222222222')
    expect(mod.CONTRACTS.stbToken).toBe('0x3333333333333333333333333333333333333333')
    expect(mod.CONTRACTS.backendBaseUrl).toBe('http://127.0.0.1:9999')
  })
})
