import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { Header } from './Header'

vi.mock('./ConnectWallet', () => ({
  ConnectWallet: () => <div>connect-wallet-mock</div>,
}))

describe('Header', () => {
  it('renders title, subtitle and wallet section', () => {
    render(<Header />)

    expect(screen.getByText('StableVault')).toBeInTheDocument()
    expect(screen.getByText('去中心化稳定币协议')).toBeInTheDocument()
    expect(screen.getByText('connect-wallet-mock')).toBeInTheDocument()
  })
})
