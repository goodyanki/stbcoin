import { render, screen } from '@testing-library/react'
import { describe, it, vi, beforeEach } from 'vitest'

import { Dashboard } from './Dashboard'

const mockUseContract = vi.fn()

vi.mock('../context/ContractContext', () => ({
  useContract: () => mockUseContract(),
}))

describe('Dashboard', () => {
  beforeEach(() => {
    mockUseContract.mockReturnValue({
      data: {
        collateral: 12,
        debt: 8000,
        collateralRatio: 180,
        liquidationPrice: 1200,
        healthFactor: 'Safe',
      },
      ethPrice: 2500,
      protocolMetrics: {
        badDebtFormatted: '0.0',
        reserveFormatted: '1.23',
      },
      backendHealthy: true,
      mcrPercent: 150,
    })
  })

  it('renders core protocol metrics', () => {
    render(<Dashboard />)

    expect(screen.getByText('ETH Price')).toBeInTheDocument()
    expect(screen.getByText('Collateral')).toBeInTheDocument()
    expect(screen.getByText('Debt')).toBeInTheDocument()
    expect(screen.getByText('Protocol Bad Debt')).toBeInTheDocument()
    expect(screen.getByText('Backend')).toBeInTheDocument()
    expect(screen.getByText('Online')).toBeInTheDocument()
  })

  it('shows liquidation guidance and distance', () => {
    render(<Dashboard />)

    expect(screen.getByText(/Liquidation Price/i)).toBeInTheDocument()
    expect(screen.getByText(/Distance to liquidation/i)).toBeInTheDocument()
  })
})
