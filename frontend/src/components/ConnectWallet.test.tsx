import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ConnectWallet } from './ConnectWallet'

const mockHooks = {
  useAccount: vi.fn(),
  useConnect: vi.fn(),
  useDisconnect: vi.fn(),
  useBalance: vi.fn(),
  useChainId: vi.fn(),
  useSwitchChain: vi.fn(),
}

vi.mock('wagmi', () => ({
  useAccount: () => mockHooks.useAccount(),
  useConnect: () => mockHooks.useConnect(),
  useDisconnect: () => mockHooks.useDisconnect(),
  useBalance: () => mockHooks.useBalance(),
  useChainId: () => mockHooks.useChainId(),
  useSwitchChain: () => mockHooks.useSwitchChain(),
}))

vi.mock('../wagmi', () => ({
  targetChain: { id: 31337, name: 'Anvil' },
}))

describe('ConnectWallet', () => {
  const connect = vi.fn()
  const disconnect = vi.fn()
  const switchChain = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
    mockHooks.useConnect.mockReturnValue({
      connect,
      connectors: [{ uid: 'injected', name: 'Injected' }],
    })
    mockHooks.useDisconnect.mockReturnValue({ disconnect })
    mockHooks.useSwitchChain.mockReturnValue({ switchChain })
    mockHooks.useBalance.mockReturnValue({
      data: { value: 2_000_000_000_000_000_000n, decimals: 18 },
    })
  })

  it('renders connect button when disconnected', async () => {
    mockHooks.useAccount.mockReturnValue({ isConnected: false, address: undefined })
    mockHooks.useChainId.mockReturnValue(31337)

    const user = userEvent.setup()
    render(<ConnectWallet />)

    const button = screen.getByRole('button', { name: /连接 Injected/i })
    expect(button).toBeInTheDocument()
    await user.click(button)
    expect(connect).toHaveBeenCalled()
  })

  it('renders switch chain button on wrong network', async () => {
    mockHooks.useAccount.mockReturnValue({
      isConnected: true,
      address: '0x1111111111111111111111111111111111111111',
    })
    mockHooks.useChainId.mockReturnValue(11155111)

    const user = userEvent.setup()
    render(<ConnectWallet />)

    const button = screen.getByRole('button', {
      name: /切换至 Anvil 31337/,
    })
    await user.click(button)
    expect(switchChain).toHaveBeenCalledWith({ chainId: 31337 })
  })

  it('shows connected account and balance', () => {
    mockHooks.useAccount.mockReturnValue({
      isConnected: true,
      address: '0x1111111111111111111111111111111111111111',
    })
    mockHooks.useChainId.mockReturnValue(31337)

    render(<ConnectWallet />)
    expect(screen.getByText('Anvil')).toBeInTheDocument()
    expect(screen.getByText('2.0000 ETH')).toBeInTheDocument()
  })
})
