import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { LiquidationDemo } from './LiquidationDemo'

const mockUseContract = vi.fn()

vi.mock('../context/ContractContext', () => ({
  useContract: () => mockUseContract(),
}))

describe('LiquidationDemo', () => {
  const setDemoMode = vi.fn().mockResolvedValue(undefined)
  const setDemoPrice = vi.fn().mockResolvedValue(undefined)
  const refresh = vi.fn().mockResolvedValue(undefined)

  beforeEach(() => {
    vi.clearAllMocks()
    mockUseContract.mockReturnValue({
      data: { healthFactor: 'Safe' },
      ethPrice: 2500,
      setDemoMode,
      setDemoPrice,
      isOwner: true,
      refresh,
    })
  })

  it('shows read-only text for non-owner', () => {
    mockUseContract.mockReturnValue({
      data: { healthFactor: 'Safe' },
      ethPrice: 2500,
      setDemoMode,
      setDemoPrice,
      isOwner: false,
      refresh,
    })

    render(<LiquidationDemo />)
    expect(
      screen.getByText(/Read-only mode: liquidation is executed by auto-keeper/i)
    ).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Apply Demo Price/i })).toBeDisabled()
  })

  it('owner can apply demo price', async () => {
    const user = userEvent.setup()
    render(<LiquidationDemo />)

    await user.click(screen.getByRole('button', { name: /Apply Demo Price/i }))

    await waitFor(() => {
      expect(setDemoMode).toHaveBeenCalledWith(true)
      expect(setDemoPrice).toHaveBeenCalled()
      expect(refresh).toHaveBeenCalled()
    })
    expect(screen.getByText('Demo price updated on-chain')).toBeInTheDocument()
  })
})
