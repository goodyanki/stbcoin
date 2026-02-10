import { useState } from 'react'
import { useContract } from '../context/ContractContext'
import { Card, Button, Alert, Typography, Row } from 'antd'
import { ReloadOutlined, SafetyOutlined } from '@ant-design/icons'

const { Text } = Typography

export function LiquidationDemo() {
  const { data, ethPrice, refresh } = useContract()
  const [loading, setLoading] = useState(false)

  const onRefresh = async () => {
    setLoading(true)
    try {
      await refresh()
    } finally {
      setLoading(false)
    }
  }

  return (
    <Card
      bordered={false}
      style={{ height: '100%', borderLeft: '4px solid #1890ff' }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <SafetyOutlined style={{ color: '#1890ff' }} />
          <span>预言机监控</span>
        </div>
      }
      extra={
        <Button icon={<ReloadOutlined />} onClick={onRefresh} loading={loading}>
          刷新
        </Button>
      }
    >
      <Text type="secondary" style={{ display: 'block', marginBottom: 16 }}>
        价格来自 Chainlink ETH/USD（Sepolia fork），前端读取合约 get_price()。
      </Text>

      <div style={{ background: '#1f1f1f', padding: 16, borderRadius: 8, marginBottom: 16 }}>
        <Row justify="space-between" align="middle">
          <Text strong>当前 ETH 价格</Text>
          <Text code style={{ fontSize: 16 }}>${ethPrice.toFixed(2)}</Text>
        </Row>
      </div>

      {data.debt > 0 && (
        <Alert
          showIcon
          type={data.healthFactor === 'Safe' ? 'success' : data.healthFactor === 'Warning' ? 'warning' : 'error'}
          message={`当前仓位状态: ${data.healthFactor}`}
          description={`抵押率 ${data.collateralRatio.toFixed(2)}%`}
        />
      )}
    </Card>
  )
}
