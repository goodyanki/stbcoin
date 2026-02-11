import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import App from './App'

vi.mock('./components/Header', () => ({
  Header: () => <div>header-mock</div>,
}))

vi.mock('./components/Dashboard', () => ({
  Dashboard: () => <div>dashboard-mock</div>,
}))

vi.mock('./components/ActionPanel', () => ({
  ActionPanel: () => <div>action-panel-mock</div>,
}))

vi.mock('./components/LiquidationDemo', () => ({
  LiquidationDemo: () => <div>liquidation-demo-mock</div>,
}))

describe('App', () => {
  it('renders core layout sections', () => {
    render(<App />)

    expect(screen.getByText('header-mock')).toBeInTheDocument()
    expect(screen.getByText('dashboard-mock')).toBeInTheDocument()
    expect(screen.getByText('action-panel-mock')).toBeInTheDocument()
    expect(screen.getByText('liquidation-demo-mock')).toBeInTheDocument()
    expect(screen.getByText(/StableVault ©/)).toBeInTheDocument()
  })
})
