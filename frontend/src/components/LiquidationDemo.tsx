import { useState } from 'react'
import { useContract } from '../context/ContractContext'
import { Card, Slider, Button, Alert, Typography, Row } from 'antd'
import { AlertOutlined, ReloadOutlined, FireOutlined } from '@ant-design/icons'

const { Text } = Typography

export function LiquidationDemo() {
    const { data, ethPrice, setEthPrice, updatePosition } = useContract()
    const [isLiquidating, setIsLiquidating] = useState(false)
    const [msg, setMsg] = useState('')

    const handlePriceChange = (value: number) => {
        setEthPrice(value)
    }

    const handleLiquidate = async () => {
        if (data.healthFactor === 'Safe') {
            setMsg("仓位安全，无法清算。")
            setTimeout(() => setMsg(''), 2000)
            return
        }

        setIsLiquidating(true)
        await new Promise(r => setTimeout(r, 1500))

        const debtValueInEth = data.debt / ethPrice
        const penalty = 1.1
        const collateralToSeize = debtValueInEth * penalty

        updatePosition('repay', data.debt)
        updatePosition('withdraw', collateralToSeize)

        setIsLiquidating(false)
        setMsg("清算触发！仓位已关闭。")
        setTimeout(() => setMsg(''), 3000)
    }

    return (
        <Card
            bordered={false}
            style={{ height: '100%', borderLeft: '4px solid #faad14' }}
            title={
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <AlertOutlined style={{ color: '#faad14' }} />
                    <span>清算控制台</span>
                </div>
            }
            extra={
                <Button
                    icon={<ReloadOutlined />}
                    onClick={() => setEthPrice(2500)}
                    title="重置价格"
                />
            }
        >
            <Text type="secondary" style={{ display: 'block', marginBottom: 24 }}>
                模拟市场波动及清算事件。
            </Text>

            <div style={{ marginBottom: 24 }}>
                <Row justify="space-between" align="middle" style={{ marginBottom: 8 }}>
                    <Text strong>预言机 ETH 价格</Text>
                    <Text code style={{ fontSize: 16 }}>${ethPrice}</Text>
                </Row>
                <Slider
                    min={1000}
                    max={4000}
                    step={50}
                    value={ethPrice}
                    onChange={handlePriceChange}
                    tooltip={{ formatter: (value) => `$${value}` }}
                />
                <Row justify="space-between" style={{ fontSize: 12, color: 'rgba(255,255,255,0.45)' }}>
                    <span>$1000</span>
                    <span>$4000</span>
                </Row>
            </div>

            <div style={{ background: '#1f1f1f', padding: 16, borderRadius: 8 }}>
                <Row justify="space-between" align="middle" style={{ marginBottom: 16 }}>
                    <Text>健康状态</Text>
                    {data.healthFactor === 'Safe' ? <Alert message="SAFE" type="success" showIcon style={{ padding: '0 8px' }} /> :
                        data.healthFactor === 'Warning' ? <Alert message="WARNING" type="warning" showIcon style={{ padding: '0 8px' }} /> :
                            <Alert message="DANGER" type="error" showIcon style={{ padding: '0 8px' }} />}
                </Row>

                <Button
                    type="primary"
                    danger
                    block
                    size="large"
                    icon={<FireOutlined />}
                    onClick={handleLiquidate}
                    loading={isLiquidating}
                    disabled={data.healthFactor === 'Safe' || data.debt === 0}
                >
                    {isLiquidating ? '正在清算...' : '触发清算'}
                </Button>
                {msg && <div style={{ marginTop: 12, textAlign: 'center', color: '#fff' }}>{msg}</div>}
            </div>
        </Card>
    )
}
