import { useState } from 'react'
import { useAccount } from 'wagmi'
import { useContract } from '../context/ContractContext'
import { Card, Tabs, InputNumber, Button, Typography, Alert, Row, Col } from 'antd'
import type { TabsProps } from 'antd'

const { Text } = Typography

type ActionType = 'deposit' | 'mint' | 'repay' | 'withdraw'

export function ActionPanel() {
    const { isConnected } = useAccount()
    const { data, ethPrice, updatePosition } = useContract()

    const [activeTab, setActiveTab] = useState<ActionType>('deposit')
    const [amount, setAmount] = useState<number | null>(null)
    const [isLoading, setIsLoading] = useState(false)
    const [isSuccess, setIsSuccess] = useState(false)

    const handleAction = async () => {
        if (!amount || amount <= 0) return
        setIsLoading(true)
        setIsSuccess(false)

        // Simulate transaction delay
        await new Promise(resolve => setTimeout(resolve, 1500))

        // Update Context State
        updatePosition(activeTab, amount)

        setIsLoading(false)
        setIsSuccess(true)
        setAmount(null)

        // Reset success message after 3s
        setTimeout(() => setIsSuccess(false), 3000)
    }

    const getActionLabel = () => {
        switch (activeTab) {
            case 'deposit': return '存入 ETH'
            case 'mint': return '铸造稳定币'
            case 'repay': return '偿还债务'
            case 'withdraw': return '取出 ETH'
        }
    }

    // Calculate projected values
    const numericAmount = amount || 0
    let projectedCollateral = data.collateral
    let projectedDebt = data.debt

    switch (activeTab) {
        case 'deposit': projectedCollateral += numericAmount; break;
        case 'withdraw': projectedCollateral = Math.max(0, projectedCollateral - numericAmount); break;
        case 'mint': projectedDebt += numericAmount; break;
        case 'repay': projectedDebt = Math.max(0, projectedDebt - numericAmount); break;
    }

    const projectedCR = projectedDebt > 0 ? (projectedCollateral * ethPrice / projectedDebt) * 100 : 0
    const currentCR = data.collateralRatio

    const onChange = (key: string) => {
        setActiveTab(key as ActionType)
        setAmount(null)
        setIsSuccess(false)
    }

    const renderForm = () => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginTop: 16 }}>
            <div>
                <div style={{ marginBottom: 8, display: 'flex', justifyContent: 'space-between' }}>
                    <Text type="secondary">数量 ({activeTab === 'deposit' || activeTab === 'withdraw' ? 'ETH' : 'STB'})</Text>
                    {activeTab === 'repay' && (
                        <Button type="link" size="small" onClick={() => setAmount(data.debt)} style={{ padding: 0 }}>
                            最大
                        </Button>
                    )}
                </div>
                <InputNumber
                    style={{ width: '100%' }}
                    size="large"
                    placeholder="0.00"
                    value={amount}
                    onChange={setAmount}
                    prefix={activeTab === 'deposit' || activeTab === 'withdraw' ? 'Ξ' : '$'}
                    disabled={!isConnected || isLoading}
                />
            </div>

            {isConnected && numericAmount > 0 && (
                <div style={{ background: '#1f1f1f', padding: 12, borderRadius: 8 }}>
                    <Row justify="space-between">
                        <Col>
                            <Text type="secondary">当前抵押率</Text>
                            <div style={{ fontSize: 16 }}>{currentCR > 0 ? currentCR.toFixed(0) : '∞'}%</div>
                        </Col>
                        <Col style={{ textAlign: 'right' }}>
                            <Text type="secondary">预计抵押率</Text>
                            <div style={{
                                fontSize: 16,
                                fontWeight: 'bold',
                                color: projectedCR < 110 ? '#ff4d4f' : projectedCR < 150 ? '#faad14' : '#52c41a'
                            }}>
                                {projectedDebt > 0 ? projectedCR.toFixed(0) + '%' : '∞'}
                            </div>
                        </Col>
                    </Row>
                </div>
            )}

            <Button
                type="primary"
                size="large"
                onClick={handleAction}
                loading={isLoading}
                disabled={!isConnected || !amount}
                block
            >
                {isSuccess ? '成功!' : getActionLabel()}
            </Button>

            {!isConnected && (
                <Alert message="请先连接钱包" type="warning" showIcon style={{ marginTop: 8 }} />
            )}
        </div>
    )

    const items: TabsProps['items'] = [
        { key: 'deposit', label: '存款', children: renderForm() },
        { key: 'mint', label: '铸造', children: renderForm() },
        { key: 'repay', label: '偿还', children: renderForm() },
        { key: 'withdraw', label: '取款', children: renderForm() },
    ]

    return (
        <Card bordered={false}>
            <Tabs defaultActiveKey="deposit" items={items} onChange={onChange} />
        </Card>
    )
}
