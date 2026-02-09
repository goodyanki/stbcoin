import { Layout, Typography } from 'antd'
import { MoneyCollectOutlined } from '@ant-design/icons'
import { ConnectWallet } from './ConnectWallet'

const { Header: AntHeader } = Layout
const { Title, Text } = Typography

export function Header() {
    return (
        <AntHeader style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 48px', background: '#001529' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div className="p-2 bg-blue-600 rounded-lg text-white flex items-center justify-center">
                    <MoneyCollectOutlined style={{ fontSize: 24 }} />
                </div>
                <div style={{ lineHeight: 1.2 }}>
                    <Title level={4} style={{ margin: 0, color: '#fff' }}>StableVault</Title>
                    <Text style={{ fontSize: 12, color: 'rgba(255,255,255,0.65)' }}>去中心化稳定币协议</Text>
                </div>
            </div>

            <ConnectWallet />
        </AntHeader>
    )
}
