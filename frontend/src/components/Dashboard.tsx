import { AlertOutlined, SafetyCertificateOutlined, WarningOutlined } from '@ant-design/icons'
import { Card, Col, Progress, Row, Statistic, Typography } from 'antd'

import { useContract } from '../context/ContractContext'

const { Text } = Typography

export function Dashboard() {
    const { data, ethPrice, protocolMetrics, backendHealthy } = useContract()

    const healthColor = (factor: string) => {
        switch (factor) {
            case 'Safe': return '#52c41a'
            case 'Warning': return '#faad14'
            case 'Danger': return '#ff4d4f'
            default: return '#1890ff'
        }
    }

    const formatCurrency = (value: number) => {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value)
    }

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            <Row gutter={24}>
                <Col span={4}>
                    <Card bordered={false}>
                        <Statistic
                            title="ETH Price"
                            value={ethPrice}
                            precision={2}
                            valueStyle={{ color: '#3f8600' }}
                            prefix="$"
                        />
                    </Card>
                </Col>
                <Col span={4}>
                    <Card bordered={false}>
                        <Statistic
                            title="Collateral"
                            value={data.collateral}
                            precision={4}
                            suffix="WETH"
                        />
                        <Text type="secondary" style={{ fontSize: 12 }}>
                            ≈ {formatCurrency(data.collateral * ethPrice)}
                        </Text>
                    </Card>
                </Col>
                <Col span={4}>
                    <Card bordered={false}>
                        <Statistic
                            title="Debt"
                            value={data.debt}
                            precision={2}
                            suffix="STB"
                        />
                    </Card>
                </Col>
                <Col span={4}>
                    <Card bordered={false}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                            <Text type="secondary">Collateral Ratio</Text>
                            {data.healthFactor === 'Safe' ? <SafetyCertificateOutlined style={{ color: '#52c41a' }} /> :
                                data.healthFactor === 'Warning' ? <WarningOutlined style={{ color: '#faad14' }} /> :
                                    <AlertOutlined style={{ color: '#ff4d4f' }} />}
                        </div>
                        <Statistic
                            value={data.collateralRatio}
                            precision={1}
                            suffix="%"
                            valueStyle={{ fontSize: 20, color: healthColor(data.healthFactor) }}
                        />
                        <Progress
                            percent={Math.min(data.collateralRatio, 240) / 2.4}
                            showInfo={false}
                            strokeColor={healthColor(data.healthFactor)}
                            size="small"
                        />
                        <div style={{ textAlign: 'right', marginTop: 4 }}>
                            <Text type="secondary" style={{ fontSize: 12 }}>Min 150%</Text>
                        </div>
                    </Card>
                </Col>
                <Col span={4}>
                    <Card bordered={false}>
                        <Statistic
                            title="Protocol Bad Debt"
                            value={protocolMetrics?.badDebtFormatted ?? '0'}
                            suffix="STB"
                        />
                        <Text type="secondary" style={{ fontSize: 12 }}>
                            Reserve: {protocolMetrics?.reserveFormatted ?? '0'} STB
                        </Text>
                    </Card>
                </Col>
                <Col span={4}>
                    <Card bordered={false}>
                        <Statistic
                            title="Backend"
                            value={backendHealthy ? 'Online' : 'Offline'}
                            valueStyle={{ color: backendHealthy ? '#52c41a' : '#ff4d4f', fontSize: 20 }}
                        />
                    </Card>
                </Col>
            </Row>

            <Card bordered={false} style={{ borderLeft: `4px solid ${healthColor(data.healthFactor)}`, background: '#1f1f1f' }}>
                <Row justify="space-between" align="middle">
                    <Col>
                        <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>Liquidation Price</Text>
                        <Text style={{ fontSize: 16 }}>
                            If ETH falls below <Text strong style={{ color: '#fff' }}>{formatCurrency(data.liquidationPrice)}</Text>, this vault can be liquidated.
                        </Text>
                    </Col>
                    <Col style={{ textAlign: 'right' }}>
                        <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>Distance to liquidation</Text>
                        <Text strong style={{ fontSize: 20, color: ethPrice > data.liquidationPrice ? '#52c41a' : '#ff4d4f' }}>
                            {ethPrice > 0 ? (((ethPrice - data.liquidationPrice) / ethPrice) * 100).toFixed(2) : '0.00'}%
                        </Text>
                    </Col>
                </Row>
            </Card>
        </div>
    )
}

