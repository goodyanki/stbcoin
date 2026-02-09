import { useContract } from '../context/ContractContext'
import { Card, Row, Col, Statistic, Progress, Typography } from 'antd'
import { SafetyCertificateOutlined, AlertOutlined, WarningOutlined } from '@ant-design/icons'

const { Text } = Typography

export function Dashboard() {
    const { data, ethPrice } = useContract()



    const healthColor = (factor: string) => {
        switch (factor) {
            case 'Safe': return '#52c41a'
            case 'Warning': return '#faad14'
            case 'Danger': return '#ff4d4f'
            default: return '#1890ff'
        }
    }

    const formatCurrency = (val: number) => {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val)
    }

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            {/* Top Stats Bar */}
            <Row gutter={24}>
                <Col span={6}>
                    <Card bordered={false}>
                        <Statistic
                            title="当前 ETH 价格"
                            value={ethPrice}
                            precision={2}
                            valueStyle={{ color: '#3f8600' }}
                            prefix="$"
                        />
                    </Card>
                </Col>
                <Col span={6}>
                    <Card bordered={false}>
                        <Statistic
                            title="我的抵押品"
                            value={data.collateral}
                            precision={4}
                            suffix="ETH"
                        />
                        <Text type="secondary" style={{ fontSize: 12 }}>
                            ≈ {formatCurrency(data.collateral * ethPrice)}
                        </Text>
                    </Card>
                </Col>
                <Col span={6}>
                    <Card bordered={false}>
                        <Statistic
                            title="我的债务"
                            value={data.debt}
                            precision={2}
                            suffix="STB"
                        />
                    </Card>
                </Col>
                <Col span={6}>
                    <Card bordered={false}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                            <Text type="secondary">抵押率</Text>
                            {data.healthFactor === 'Safe' ? <SafetyCertificateOutlined style={{ color: '#52c41a' }} /> :
                                data.healthFactor === 'Warning' ? <WarningOutlined style={{ color: '#faad14' }} /> :
                                    <AlertOutlined style={{ color: '#ff4d4f' }} />}
                        </div>
                        <Statistic
                            value={data.collateralRatio}
                            precision={0}
                            suffix="%"
                            valueStyle={{ fontSize: 20, color: healthColor(data.healthFactor) }}
                        />
                        <Progress
                            percent={Math.min(data.collateralRatio, 200) / 2}
                            showInfo={false}
                            strokeColor={healthColor(data.healthFactor)}
                            size="small"
                        />
                        <div style={{ textAlign: 'right', marginTop: 4 }}>
                            <Text type="secondary" style={{ fontSize: 12 }}>最低 110%</Text>
                        </div>
                    </Card>
                </Col>
            </Row>

            {/* Liquidation Info */}
            <Card bordered={false} style={{ borderLeft: `4px solid ${healthColor(data.healthFactor)}`, background: '#1f1f1f' }}>
                <Row justify="space-between" align="middle">
                    <Col>
                        <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>清算价格</Text>
                        <Text style={{ fontSize: 16 }}>
                            若 ETH 跌破 <Text strong style={{ color: '#fff' }}>{formatCurrency(data.liquidationPrice)}</Text>，您的仓位将被清算
                        </Text>
                    </Col>
                    <Col style={{ textAlign: 'right' }}>
                        <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>距离清算</Text>
                        <Text strong style={{ fontSize: 20, color: ethPrice > data.liquidationPrice ? '#52c41a' : '#ff4d4f' }}>
                            {formatNumber(((ethPrice - data.liquidationPrice) / ethPrice) * 100, 2)}%
                        </Text>
                    </Col>
                </Row>
            </Card>
        </div>
    )
}

function formatNumber(val: number, decimals = 2) {
    return val.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals })
}
