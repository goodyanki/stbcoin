import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, beforeEach, vi } from 'vitest'

import { ContractProvider, useContract } from './ContractContext'

const accountAddress = '0x1111111111111111111111111111111111111111' as const

const mockUseAccount = vi.fn()
const mockUsePublicClient = vi.fn()
const mockUseWalletClient = vi.fn()

const mockReadContract = vi.fn()
const mockWaitForReceipt = vi.fn().mockResolvedValue({ status: 'success' })
const mockWriteContract = vi.fn().mockResolvedValue('0xhash')

vi.mock('wagmi', () => ({
  useAccount: () => mockUseAccount(),
  usePublicClient: () => mockUsePublicClient(),
  useWalletClient: () => mockUseWalletClient(),
}))

vi.mock('../config/contracts', () => ({
  CONTRACTS: {
    stableVault: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    oracleHub: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    stbToken: '0xcccccccccccccccccccccccccccccccccccccccc',
    backendBaseUrl: 'http://localhost:8080',
  },
  ERC20_ABI: [],
  ORACLE_HUB_ABI: [],
  STABLE_VAULT_ABI: [],
}))

function TestConsumer() {
  const ctx = useContract()
  return (
    <div>
      <div data-testid="collateral">{ctx.data.collateral}</div>
      <div data-testid="debt">{ctx.data.debt}</div>
      <div data-testid="price">{ctx.ethPrice}</div>
      <div data-testid="owner">{ctx.isOwner ? 'owner' : 'not-owner'}</div>
      <div data-testid="backend">{ctx.backendHealthy ? 'online' : 'offline'}</div>
      <button onClick={() => void ctx.performAction('repay', 2)}>repay</button>
    </div>
  )
}

describe('ContractProvider', () => {
  beforeEach(() => {
    vi.clearAllMocks()

    mockUseAccount.mockReturnValue({
      address: accountAddress,
      isConnected: true,
    })

    mockUsePublicClient.mockReturnValue({
      readContract: mockReadContract,
      waitForTransactionReceipt: mockWaitForReceipt,
    })

    mockUseWalletClient.mockReturnValue({
      data: {
        writeContract: mockWriteContract,
        chain: { id: 31337 },
      },
    })

    mockReadContract.mockImplementation(({ functionName }: { functionName: string }) => {
      if (functionName === 'getVault') {
        return Promise.resolve([1_000_000_000_000_000_000n, 0n, 0n, 500_000_000_000_000_000_000n, 0n, 0n])
      }
      if (functionName === 'getCollateralRatioBps') return Promise.resolve(20_000n)
      if (functionName === 'getPriceStatus') return Promise.resolve([2_500_000_000_000_000_000_000n, 0n, 0n, 0n, 0n, false] as const)
      if (functionName === 'owner') return Promise.resolve(accountAddress)
      if (functionName === 'allowance') return Promise.resolve(0n)
      return Promise.resolve(0n)
    })

    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) => {
        if (url.endsWith('/health')) {
          return Promise.resolve(new Response('{}', { status: 200 }))
        }
        if (url.endsWith('/v1/protocol/metrics')) {
          return Promise.resolve(
            new Response(JSON.stringify({ badDebtFormatted: '0', reserveFormatted: '1' }), { status: 200 })
          )
        }
        return Promise.resolve(new Response('{}', { status: 404 }))
      })
    )
  })

  it('loads on-chain and backend data on mount', async () => {
    render(
      <ContractProvider>
        <TestConsumer />
      </ContractProvider>
    )

    await waitFor(() => {
      expect(screen.getByTestId('collateral')).toHaveTextContent('1')
      expect(screen.getByTestId('debt')).toHaveTextContent('500')
      expect(screen.getByTestId('price')).toHaveTextContent('2500')
      expect(screen.getByTestId('owner')).toHaveTextContent('owner')
      expect(screen.getByTestId('backend')).toHaveTextContent('online')
    })
  })

  it('handles repay flow with approval then repay tx', async () => {
    const user = userEvent.setup()

    render(
      <ContractProvider>
        <TestConsumer />
      </ContractProvider>
    )

    await user.click(screen.getByRole('button', { name: 'repay' }))

    await waitFor(() => {
      expect(mockWriteContract).toHaveBeenCalled()
      expect(mockWaitForReceipt).toHaveBeenCalled()
    })

    const fnNames = mockWriteContract.mock.calls.map(
      (call: unknown[]) => (call[0] as { functionName: string }).functionName
    )
    expect(fnNames).toContain('approve')
    expect(fnNames).toContain('repay')
  })
})
