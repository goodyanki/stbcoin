import { useState } from 'react'
import { AlertOutlined, ReloadOutlined } from '@ant-design/icons'
import { Alert, Button, Card, Row, Slider, Switch, Typography } from 'antd'

import { useContract } from '../context/ContractContext'

const { Text } = Typography

export function LiquidationDemo() {
    const { data, ethPrice, setDemoMode, setDemoPrice, isOwner, refresh } = useContract()

    const [priceDraft, setPriceDraft] = useState<number>(Math.round(ethPrice || 2500))
    const [isLoading, setIsLoading] = useState(false)
    const [message, setMessage] = useState('')

    const handleAdminPriceUpdate = async () => {
        if (!isOwner) {
            setMessage('Only owner can update demo price')
            return
        }

        setIsLoading(true)
        try {
            await setDemoMode(true)
            await setDemoPrice(priceDraft)
            await refresh()
            setMessage('Demo price updated on-chain')
        } catch (error) {
            setMessage(error instanceof Error ? error.message : 'Failed to update demo price')
        } finally {
            setIsLoading(false)
        }
    }

    return (
        <Card
            bordered={false}
            style={{ height: '100%', borderLeft: '4px solid #faad14' }}
            title={
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <AlertOutlined style={{ color: '#faad14' }} />
                    <span>Liquidation Control</span>
                </div>
            }
            extra={
                <Button icon={<ReloadOutlined />} onClick={() => { setPriceDraft(Math.round(ethPrice || 2500)); void refresh() }} />
            }
        >
            <Text type="secondary" style={{ display: 'block', marginBottom: 24 }}>
                Simulate price changes and trigger liquidation flow.
            </Text>

            <div style={{ marginBottom: 24 }}>
                <Row justify="space-between" align="middle" style={{ marginBottom: 8 }}>
                    <Text strong>Demo ETH Price</Text>
                    <Text code style={{ fontSize: 16 }}>${priceDraft}</Text>
                </Row>
                <Slider
                    min={0}
                    max={4000}
                    step={10}
                    value={priceDraft}
                    onChange={(value) => setPriceDraft(value)}
                    tooltip={{ formatter: (value) => `$${value}` }}
                    disabled={!isOwner || isLoading}
                />
                <Row justify="space-between" style={{ fontSize: 12, color: 'rgba(255,255,255,0.45)' }}>
                    <span>$900</span>
                    <span>$4000</span>
                </Row>
                <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
                    <Button type="default" onClick={() => void handleAdminPriceUpdate()} loading={isLoading} disabled={!isOwner}>
                        Apply Demo Price
                    </Button>
                    {isOwner && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <Switch checked disabled />
                            <Text type="secondary">Demo mode enabled</Text>
                        </div>
                    )}
                </div>
            </div>

            <div style={{ background: '#1f1f1f', padding: 16, borderRadius: 8 }}>
                <Row justify="space-between" align="middle" style={{ marginBottom: 16 }}>
                    <Text>Health</Text>
                    {data.healthFactor === 'Safe' ? <Alert message="SAFE" type="success" showIcon style={{ padding: '0 8px' }} /> :
                        data.healthFactor === 'Warning' ? <Alert message="WARNING" type="warning" showIcon style={{ padding: '0 8px' }} /> :
                            <Alert message="DANGER" type="error" showIcon style={{ padding: '0 8px' }} />}
                </Row>

                <Alert
                    type={data.healthFactor === 'Safe' ? 'success' : data.healthFactor === 'Warning' ? 'warning' : 'error'}
                    showIcon
                    message={
                        isOwner
                            ? 'Admin mode: adjust demo price and let auto-keeper execute liquidation.'
                            : 'Read-only mode: liquidation is executed by auto-keeper when vault turns dangerous.'
                    }
                />

                {!!message && <div style={{ marginTop: 12, textAlign: 'center', color: '#fff' }}>{message}</div>}
            </div>
        </Card>
    )
}

