import { useState } from 'react'
import { parseEther } from 'viem'
import { useAccount, usePublicClient, useWriteContract } from 'wagmi'
import { useContract } from '../context/ContractContext'
import { Card, Tabs, InputNumber, Button, Typography, Alert, Row, Col } from 'antd'
import type { TabsProps } from 'antd'
import { CONTRACTS, STABILITY_ENGINE_ABI, STABLECOIN_ABI, VAULT_MANAGER_ABI } from '../contracts'

const { Text } = Typography

type ActionType = 'deposit' | 'mint' | 'repay' | 'withdraw'

export function ActionPanel() {
  const { isConnected } = useAccount()
  const publicClient = usePublicClient()
  const { writeContractAsync } = useWriteContract()
  const { data, ethPrice, mcrPercent, refresh, contractsReady } = useContract()

  const [activeTab, setActiveTab] = useState<ActionType>('deposit')
  const [amount, setAmount] = useState<number | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [error, setError] = useState<string>('')

  const waitTx = async (hash: `0x${string}`) => {
    if (!publicClient) throw new Error('public client unavailable')
    await publicClient.waitForTransactionReceipt({ hash })
  }

  const ensureVault = async () => {
    if (data.exists) return
    const hash = await writeContractAsync({
      address: CONTRACTS.vaultManager!,
      abi: VAULT_MANAGER_ABI,
      functionName: 'open_vault',
    })
    await waitTx(hash)
  }

  const handleAction = async () => {
    if (!amount || amount <= 0 || !contractsReady || !isConnected) return

    setIsLoading(true)
    setIsSuccess(false)
    setError('')

    try {
      const value = parseEther(amount.toString())

      if (activeTab === 'deposit' || activeTab === 'mint' || activeTab === 'withdraw') {
        await ensureVault()
      }

      if (activeTab === 'deposit') {
        const hash = await writeContractAsync({
          address: CONTRACTS.vaultManager!,
          abi: VAULT_MANAGER_ABI,
          functionName: 'deposit_collateral',
          value,
        })
        await waitTx(hash)
      }

      if (activeTab === 'mint') {
        const hash = await writeContractAsync({
          address: CONTRACTS.stabilityEngine!,
          abi: STABILITY_ENGINE_ABI,
          functionName: 'mint',
          args: [value],
        })
        await waitTx(hash)
      }

      if (activeTab === 'repay') {
        const approveHash = await writeContractAsync({
          address: CONTRACTS.stablecoin!,
          abi: STABLECOIN_ABI,
          functionName: 'approve',
          args: [CONTRACTS.stabilityEngine!, value],
        })
        await waitTx(approveHash)

        const repayHash = await writeContractAsync({
          address: CONTRACTS.stabilityEngine!,
          abi: STABILITY_ENGINE_ABI,
          functionName: 'repay',
          args: [value],
        })
        await waitTx(repayHash)
      }

      if (activeTab === 'withdraw') {
        const hash = await writeContractAsync({
          address: CONTRACTS.stabilityEngine!,
          abi: STABILITY_ENGINE_ABI,
          functionName: 'withdraw_collateral',
          args: [value],
        })
        await waitTx(hash)
      }

      await refresh()
      setIsSuccess(true)
      setAmount(null)
      setTimeout(() => setIsSuccess(false), 3000)
    } catch (e) {
      const message = e instanceof Error ? e.message : 'transaction failed'
      setError(message)
    } finally {
      setIsLoading(false)
    }
  }

  const getActionLabel = () => {
    switch (activeTab) {
      case 'deposit': return '存入 ETH'
      case 'mint': return '铸造稳定币'
      case 'repay': return '偿还债务'
      case 'withdraw': return '取出 ETH'
    }
  }

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

  const onChange = (key: string) => {
    setActiveTab(key as ActionType)
    setAmount(null)
    setIsSuccess(false)
    setError('')
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
          disabled={!isConnected || isLoading || !contractsReady}
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
        {isSuccess ? '成功!' : getActionLabel()}
      </Button>

      {!contractsReady && (
        <Alert message="请先在 .env 配置合约地址" type="warning" showIcon />
      )}

      {!isConnected && (
        <Alert message="请先连接钱包" type="warning" showIcon style={{ marginTop: 8 }} />
      )}

      {error && (
        <Alert message={error} type="error" showIcon />
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
