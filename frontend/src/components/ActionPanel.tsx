import { useState } from 'react'
import { Alert, Button, Card, Col, InputNumber, Row, Tabs, Typography } from 'antd'
import type { TabsProps } from 'antd'
import { useAccount } from 'wagmi'

import { useContract } from '../context/ContractContext'

const { Text } = Typography

type ActionType = 'deposit' | 'mint' | 'repay' | 'withdraw'

export function ActionPanel() {
    const { isConnected } = useAccount()
    const { data, ethPrice, performAction, refresh, contractsReady, mcrPercent } = useContract()

    const [activeTab, setActiveTab] = useState<ActionType>('deposit')
    const [amount, setAmount] = useState<number | null>(null)
    const [isLoading, setIsLoading] = useState(false)
    const [feedback, setFeedback] = useState<string>('')

    const numericAmount = amount || 0
    let projectedCollateral = data.collateral
    let projectedDebt = data.debt

    switch (activeTab) {
        case 'deposit': projectedCollateral += numericAmount; break
        case 'withdraw': projectedCollateral = Math.max(0, projectedCollateral - numericAmount); break
        case 'mint': projectedDebt += numericAmount; break
        case 'repay': projectedDebt = Math.max(0, projectedDebt - numericAmount); break
    }

    const projectedCR = projectedDebt > 0 ? (projectedCollateral * ethPrice / projectedDebt) * 100 : 0
    const currentCR = data.collateralRatio

    const getActionLabel = () => {
        switch (activeTab) {
            case 'deposit': return 'Deposit ETH'
            case 'mint': return 'Mint STB'
            case 'repay': return 'Repay STB'
            case 'withdraw': return 'Withdraw ETH'
        }
    }

    const handleAction = async () => {
        if (!amount || amount <= 0) return
        setIsLoading(true)
        setFeedback('')

        try {
            await performAction(activeTab, amount)
            await refresh()
            setFeedback('Transaction confirmed')
            setAmount(null)
        } catch (error) {
            const message = error instanceof Error ? error.message : 'Transaction failed'
            setFeedback(message)
        } finally {
            setIsLoading(false)
        }
    }

    const onChange = (key: string) => {
        setActiveTab(key as ActionType)
        setAmount(null)
        setFeedback('')
    }

    const renderForm = () => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginTop: 16 }}>
            <div>
                <div style={{ marginBottom: 8, display: 'flex', justifyContent: 'space-between' }}>
                    <Text type="secondary">Amount ({activeTab === 'deposit' || activeTab === 'withdraw' ? 'ETH' : 'STB'})</Text>
                    {activeTab === 'repay' && (
                        <Button type="link" size="small" onClick={() => setAmount(data.debt)} style={{ padding: 0 }}>
                            Max
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
                            <Text type="secondary">Current CR</Text>
                            <div style={{ fontSize: 16 }}>{currentCR > 0 ? currentCR.toFixed(0) : '∞'}%</div>
                        </Col>
                        <Col style={{ textAlign: 'right' }}>
                            <Text type="secondary">Projected CR</Text>
                            <div style={{
                                fontSize: 16,
                                fontWeight: 'bold',
                                color: projectedCR < mcrPercent ? '#ff4d4f' : projectedCR < mcrPercent + 20 ? '#faad14' : '#52c41a'
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
                disabled={!isConnected || !amount || !contractsReady}
                block
            >
                {getActionLabel()}
            </Button>

            {!contractsReady && (
                <Alert message="Please configure contract addresses in frontend .env first" type="warning" showIcon />
            )}

            {!isConnected && (
                <Alert message="Please connect your wallet first" type="warning" showIcon />
            )}

            {!!feedback && (
                <Alert
                    message={feedback}
                    type={feedback === 'Transaction confirmed' ? 'success' : 'error'}
                    showIcon
                />
            )}
        </div>
    )

    const items: TabsProps['items'] = [
        { key: 'deposit', label: 'Deposit', children: renderForm() },
        { key: 'mint', label: 'Mint', children: renderForm() },
        { key: 'repay', label: 'Repay', children: renderForm() },
        { key: 'withdraw', label: 'Withdraw', children: renderForm() },
    ]

    return (
        <Card bordered={false}>
            <Tabs defaultActiveKey="deposit" items={items} onChange={onChange} />
        </Card>
    )
}
