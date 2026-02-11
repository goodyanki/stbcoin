import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ActionPanel } from './ActionPanel'

const mockUseAccount = vi.fn()
const mockUseContract = vi.fn()

vi.mock('wagmi', () => ({
  useAccount: () => mockUseAccount(),
}))

vi.mock('../context/ContractContext', () => ({
  useContract: () => mockUseContract(),
}))

describe('ActionPanel', () => {
  const performAction = vi.fn()
  const refresh = vi.fn().mockResolvedValue(undefined)

  beforeEach(() => {
    vi.clearAllMocks()
    mockUseAccount.mockReturnValue({ isConnected: true })
    mockUseContract.mockReturnValue({
      data: {
        collateral: 10,
        debt: 5000,
        collateralRatio: 200,
      },
      ethPrice: 2500,
      performAction,
      refresh,
      contractsReady: true,
      mcrPercent: 150,
    })
  })

  it('disables action when wallet disconnected', () => {
    mockUseAccount.mockReturnValue({ isConnected: false })
    render(<ActionPanel />)

    expect(screen.getByText('Please connect your wallet first')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Deposit ETH' })).toBeDisabled()
  })

  it('submits deposit action and shows success feedback', async () => {
    performAction.mockResolvedValue(undefined)
    const user = userEvent.setup()

    render(<ActionPanel />)

    const input = screen.getByRole('spinbutton')
    await user.clear(input)
    await user.type(input, '1')
    await user.click(screen.getByRole('button', { name: 'Deposit ETH' }))

    await waitFor(() => {
      expect(performAction).toHaveBeenCalledWith('deposit', 1)
    })
    expect(screen.getByText('Transaction confirmed')).toBeInTheDocument()
  })

  it('shows projected CR on mint tab', async () => {
    const user = userEvent.setup()
    render(<ActionPanel />)

    await user.click(screen.getByRole('tab', { name: 'Mint' }))
    const input = screen.getByRole('spinbutton')
    await user.clear(input)
    await user.type(input, '100')

    expect(screen.getAllByText('Projected CR').length).toBeGreaterThan(0)
  })
})
