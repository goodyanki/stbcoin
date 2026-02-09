import { useAccount, useConnect, useDisconnect, useBalance, useChainId, useSwitchChain } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { WalletOutlined, LogoutOutlined, DownOutlined, WarningOutlined } from '@ant-design/icons'
import { Button, Dropdown, Tag, Typography, Space } from 'antd'
import type { MenuProps } from 'antd'

const { Text } = Typography

export function ConnectWallet() {
    const { address, isConnected } = useAccount()
    const { connect, connectors } = useConnect()
    const { disconnect } = useDisconnect()
    const { switchChain } = useSwitchChain()
    const chainId = useChainId()

    const { data: balance } = useBalance({
        address,
    })

    // Format address: 0x1234...5678
    const formatAddress = (addr: string) => {
        return `${addr.slice(0, 6)}...${addr.slice(-4)}`
    }

    // Format balance to 4 decimals
    const formatBalance = (value?: bigint, decimals = 18) => {
        if (!value) return '0'
        const bal = Number(value) / 10 ** decimals
        return bal.toFixed(4)
    }

    if (!isConnected) {
        return (
            <div style={{ display: 'flex', gap: 8 }}>
                {connectors.map((connector) => (
                    <Button
                        key={connector.uid}
                        type="primary"
                        icon={<WalletOutlined />}
                        onClick={() => connect({ connector })}
                    >
                        连接 {connector.name}
                    </Button>
                ))}
            </div>
        )
    }

    if (chainId !== sepolia.id) {
        return (
            <Button
                type="primary"
                danger
                icon={<WarningOutlined />}
                onClick={() => switchChain({ chainId: sepolia.id })}
            >
                切换至 Sepolia
            </Button>
        )
    }

    const items: MenuProps['items'] = [
        {
            key: 'disconnect',
            label: '断开连接',
            icon: <LogoutOutlined />,
            danger: true,
            onClick: () => disconnect(),
        },
    ]

    return (
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            {/* Network Badge */}
            <Tag color="success">Sepolia</Tag>

            {/* Balance */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', lineHeight: 1.2 }}>
                <Text style={{ color: '#fff', fontWeight: 500 }}>
                    {formatBalance(balance?.value, balance?.decimals)} ETH
                </Text>
                <Text type="secondary" style={{ fontSize: 10 }}>余额</Text>
            </div>

            {/* Address & Disconnect */}
            <Dropdown menu={{ items }} placement="bottomRight">
                <Button>
                    <Space>
                        {formatAddress(address as string)}
                        <DownOutlined />
                    </Space>
                </Button>
            </Dropdown>
        </div>
    )
}
