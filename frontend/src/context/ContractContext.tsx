import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { formatEther } from 'viem'
import { useAccount, usePublicClient } from 'wagmi'
import { CONTRACTS, contractsReady, ORACLE_ABI, STABILITY_ENGINE_ABI, VAULT_MANAGER_ABI } from '../contracts'

export interface UserPosition {
  collateral: number
  debt: number
  collateralRatio: number
  liquidationPrice: number
  healthFactor: 'Safe' | 'Warning' | 'Danger'
  maxLTV: number
  exists: boolean
}

interface ContractContextType {
  data: UserPosition
  ethPrice: number
  mcrPercent: number
  contractsReady: boolean
  refresh: () => Promise<void>
}

const emptyPosition: UserPosition = {
  collateral: 0,
  debt: 0,
  collateralRatio: 0,
  liquidationPrice: 0,
  healthFactor: 'Safe',
  maxLTV: 0,
  exists: false,
}

const ContractContext = createContext<ContractContextType | undefined>(undefined)

export function ContractProvider({ children }: { children: ReactNode }) {
  const { address, isConnected } = useAccount()
  const publicClient = usePublicClient()

  const [ethPrice, setEthPrice] = useState(0)
  const [mcrPercent, setMcrPercent] = useState(150)
  const [data, setData] = useState<UserPosition>(emptyPosition)

  const refresh = useCallback(async () => {
    if (!isConnected || !address || !publicClient || !contractsReady) {
      setData(emptyPosition)
      setEthPrice(0)
      return
    }

    try {
      const [vaultResult, rawCr, rawPrice, rawMcr] = await Promise.all([
        publicClient.readContract({
          address: CONTRACTS.vaultManager!,
          abi: VAULT_MANAGER_ABI,
          functionName: 'get_vault',
          args: [address],
        }),
        publicClient.readContract({
          address: CONTRACTS.vaultManager!,
          abi: VAULT_MANAGER_ABI,
          functionName: 'collateral_ratio',
          args: [address],
        }),
        publicClient.readContract({
          address: CONTRACTS.oracle!,
          abi: ORACLE_ABI,
          functionName: 'get_price',
        }),
        publicClient.readContract({
          address: CONTRACTS.stabilityEngine!,
          abi: STABILITY_ENGINE_ABI,
          functionName: 'mcr',
        }),
      ])

      const { collateral: collateralRaw, debt: debtRaw, exists } = vaultResult as {
        collateral: bigint
        debt: bigint
        exists: boolean
      }

      const collateral = Number(formatEther(collateralRaw))
      const debt = Number(formatEther(debtRaw))
      const nextEthPrice = Number(formatEther(rawPrice as bigint))
      const nextMcrPercent = Number(rawMcr as bigint) * 100 / 1e18

      const crRaw = rawCr as bigint
      const crPercent = debtRaw === 0n || crRaw > 10n ** 36n ? 9999 : Number(crRaw) * 100 / 1e18

      let health: 'Safe' | 'Warning' | 'Danger' = 'Safe'
      if (crPercent < nextMcrPercent) health = 'Danger'
      else if (crPercent < nextMcrPercent + 20) health = 'Warning'

      const liquidationPrice = collateralRaw > 0n && debtRaw > 0n
        ? Number(formatEther(((rawMcr as bigint) * debtRaw) / collateralRaw))
        : 0

      setEthPrice(nextEthPrice)
      setMcrPercent(nextMcrPercent)
      setData({
        collateral,
        debt,
        collateralRatio: crPercent,
        liquidationPrice,
        healthFactor: health,
        maxLTV: nextMcrPercent > 0 ? 100 / nextMcrPercent : 0,
        exists,
      })
    } catch {
      setData(emptyPosition)
      setEthPrice(0)
    }
  }, [address, isConnected, publicClient])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const value = useMemo(() => ({ data, ethPrice, mcrPercent, contractsReady, refresh }), [data, ethPrice, mcrPercent, refresh])

  return <ContractContext.Provider value={value}>{children}</ContractContext.Provider>
}

export const useContract = () => {
  const context = useContext(ContractContext)
  if (!context) throw new Error('useContract must be used within a ContractProvider')
  return context
}
