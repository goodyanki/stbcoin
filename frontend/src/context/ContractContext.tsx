import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { formatUnits, parseUnits } from 'viem'
import { useAccount, usePublicClient, useWalletClient } from 'wagmi'

import { CONTRACTS, ERC20_ABI, ORACLE_HUB_ABI, STABLE_VAULT_ABI } from '../config/contracts'

type ActionType = 'deposit' | 'mint' | 'repay' | 'withdraw' | 'liquidate'

export interface UserPosition {
    collateral: number
    debt: number
    collateralRatio: number
    liquidationPrice: number
    healthFactor: 'Safe' | 'Warning' | 'Danger'
    maxLTV: number
}

export interface ProtocolMetrics {
    badDebtFormatted: string
    reserveFormatted: string
}

interface ContractContextType {
    data: UserPosition
    ethPrice: number
    refresh: () => Promise<void>
    performAction: (type: ActionType, amount: number, ownerAddress?: `0x${string}`) => Promise<void>
    setDemoPrice: (price: number) => Promise<void>
    setDemoMode: (enabled: boolean) => Promise<void>
    isOwner: boolean
    protocolMetrics: ProtocolMetrics | null
    backendHealthy: boolean
    contractsReady: boolean
    mcrPercent: number
}

const defaultPosition: UserPosition = {
    collateral: 0,
    debt: 0,
    collateralRatio: 0,
    liquidationPrice: 0,
    healthFactor: 'Safe',
    maxLTV: 1.5,
}

const ContractContext = createContext<ContractContextType | undefined>(undefined)

function mapHealth(collateralRatioPercent: number): 'Safe' | 'Warning' | 'Danger' {
    if (collateralRatioPercent < 150) return 'Danger'
    if (collateralRatioPercent < 170) return 'Warning'
    return 'Safe'
}

export function ContractProvider({ children }: { children: ReactNode }) {
    const { address, isConnected } = useAccount()
    const publicClient = usePublicClient()
    const { data: walletClient } = useWalletClient()

    const [data, setData] = useState<UserPosition>(defaultPosition)
    const [ethPrice, setEthPrice] = useState(2500)
    const [ownerAddress, setOwnerAddress] = useState<`0x${string}` | null>(null)
    const [protocolMetrics, setProtocolMetrics] = useState<ProtocolMetrics | null>(null)
    const [backendHealthy, setBackendHealthy] = useState(false)

    const contractsReady = useMemo(
        () => Boolean(CONTRACTS.stableVault && CONTRACTS.oracleHub && CONTRACTS.stbToken),
        []
    )
    const mcrPercent = 150

    const isOwner = useMemo(() => {
        if (!address || !ownerAddress) return false
        return address.toLowerCase() === ownerAddress.toLowerCase()
    }, [address, ownerAddress])

    const loadBackend = useCallback(async () => {
        try {
            const [healthRes, metricsRes] = await Promise.all([
                fetch(`${CONTRACTS.backendBaseUrl}/health`),
                fetch(`${CONTRACTS.backendBaseUrl}/v1/protocol/metrics`)
            ])

            setBackendHealthy(healthRes.ok)

            if (metricsRes.ok) {
                const metrics = await metricsRes.json() as { badDebtFormatted: string; reserveFormatted: string }
                setProtocolMetrics(metrics)
            }
        } catch {
            setBackendHealthy(false)
        }
    }, [])

    const refresh = useCallback(async () => {
        if (!isConnected || !address || !publicClient || !CONTRACTS.stableVault) {
            setData(defaultPosition)
            return
        }

        try {
            const [vaultRes, ratioRes, oracleRes, ownerRes] = await Promise.allSettled([
                publicClient.readContract({
                    address: CONTRACTS.stableVault,
                    abi: STABLE_VAULT_ABI,
                    functionName: 'getVault',
                    args: [address],
                }),
                publicClient.readContract({
                    address: CONTRACTS.stableVault,
                    abi: STABLE_VAULT_ABI,
                    functionName: 'getCollateralRatioBps',
                    args: [address],
                }),
                CONTRACTS.oracleHub
                    ? publicClient.readContract({
                        address: CONTRACTS.oracleHub,
                        abi: ORACLE_HUB_ABI,
                        functionName: 'getPriceStatus',
                    })
                    : Promise.resolve([BigInt(0), BigInt(0), BigInt(0), BigInt(0), BigInt(0), false] as const),
                publicClient.readContract({
                    address: CONTRACTS.stableVault,
                    abi: STABLE_VAULT_ABI,
                    functionName: 'owner',
                }),
            ])

            if (vaultRes.status !== 'fulfilled' || ownerRes.status !== 'fulfilled') {
                setData(defaultPosition)
                return
            }

            const vaultRaw = vaultRes.value
            const ownerRaw = ownerRes.value
            const oracleStatus =
                oracleRes.status === 'fulfilled'
                    ? oracleRes.value
                    : ([BigInt(0), BigInt(0), BigInt(0), BigInt(0), BigInt(0), false] as const)

            const collateral = Number(formatUnits(vaultRaw[0], 18))
            const debt = Number(formatUnits(vaultRaw[3], 18))
            const effectivePrice = Number(formatUnits(oracleStatus[0], 18))
            const liquidationPrice = collateral > 0 ? (1.5 * debt) / collateral : 0
            const ratioPercent = ratioRes.status === 'fulfilled'
                ? Number(ratioRes.value) / 100
                : (debt > 0 && effectivePrice > 0 ? (collateral * effectivePrice / debt) * 100 : 0)

            setEthPrice(effectivePrice || 2500)
            setOwnerAddress(ownerRaw)

            setData({
                collateral,
                debt,
                collateralRatio: Number.isFinite(ratioPercent) && ratioPercent < 1e9 ? ratioPercent : 0,
                liquidationPrice,
                healthFactor: mapHealth(ratioPercent),
                maxLTV: 1.5,
            })
        } catch {
            setData(defaultPosition)
        }
    }, [address, isConnected, publicClient])

    const ensureApproval = useCallback(async (tokenAddress: `0x${string}`, amount: bigint) => {
        if (!publicClient || !walletClient || !address || !CONTRACTS.stableVault) return

        const allowance = await publicClient.readContract({
            address: tokenAddress,
            abi: ERC20_ABI,
            functionName: 'allowance',
            args: [address, CONTRACTS.stableVault],
        })

        if (allowance < amount) {
            const hash = await walletClient.writeContract({
                address: tokenAddress,
                abi: ERC20_ABI,
                functionName: 'approve',
                args: [CONTRACTS.stableVault, amount],
                account: address,
                chain: walletClient.chain,
            })
            await publicClient.waitForTransactionReceipt({ hash })
        }
    }, [address, publicClient, walletClient])

    const performAction = useCallback(async (type: ActionType, amount: number, targetOwner?: `0x${string}`) => {
        if (!walletClient || !publicClient || !address || !CONTRACTS.stableVault) {
            throw new Error('Wallet or contract not configured')
        }

        const parsed = parseUnits(String(amount), 18)

        if ((type === 'repay' || type === 'liquidate') && CONTRACTS.stbToken) {
            await ensureApproval(CONTRACTS.stbToken, parsed)
        }

        if (type === 'deposit') {
            const hash = await walletClient.writeContract({
                address: CONTRACTS.stableVault,
                abi: STABLE_VAULT_ABI,
                functionName: 'deposit',
                args: [parsed],
                value: parsed,
                account: address,
                chain: walletClient.chain,
            })
            await publicClient.waitForTransactionReceipt({ hash })
        }

        if (type === 'withdraw') {
            const hash = await walletClient.writeContract({
                address: CONTRACTS.stableVault,
                abi: STABLE_VAULT_ABI,
                functionName: 'withdraw',
                args: [parsed],
                account: address,
                chain: walletClient.chain,
            })
            await publicClient.waitForTransactionReceipt({ hash })
        }

        if (type === 'mint') {
            const hash = await walletClient.writeContract({
                address: CONTRACTS.stableVault,
                abi: STABLE_VAULT_ABI,
                functionName: 'mint',
                args: [parsed],
                account: address,
                chain: walletClient.chain,
            })
            await publicClient.waitForTransactionReceipt({ hash })
        }

        if (type === 'repay') {
            const hash = await walletClient.writeContract({
                address: CONTRACTS.stableVault,
                abi: STABLE_VAULT_ABI,
                functionName: 'repay',
                args: [parsed],
                account: address,
                chain: walletClient.chain,
            })
            await publicClient.waitForTransactionReceipt({ hash })
        }

        if (type === 'liquidate') {
            if (!targetOwner) throw new Error('owner address required for liquidation')
            const hash = await walletClient.writeContract({
                address: CONTRACTS.stableVault,
                abi: STABLE_VAULT_ABI,
                functionName: 'liquidate',
                args: [targetOwner, parsed],
                account: address,
                chain: walletClient.chain,
            })
            await publicClient.waitForTransactionReceipt({ hash })
        }

        await refresh()
        await loadBackend()
    }, [address, ensureApproval, loadBackend, publicClient, refresh, walletClient])

    const setDemoMode = useCallback(async (enabled: boolean) => {
        if (!walletClient || !publicClient || !address || !CONTRACTS.stableVault) {
            throw new Error('Wallet or contract not configured')
        }
        const hash = await walletClient.writeContract({
            address: CONTRACTS.stableVault,
            abi: STABLE_VAULT_ABI,
            functionName: 'setDemoMode',
            args: [enabled],
            account: address,
            chain: walletClient.chain,
        })
        await publicClient.waitForTransactionReceipt({ hash })
        await refresh()
    }, [address, publicClient, refresh, walletClient])

    const setDemoPrice = useCallback(async (price: number) => {
        if (!walletClient || !publicClient || !address || !CONTRACTS.stableVault) {
            throw new Error('Wallet or contract not configured')
        }
        const hash = await walletClient.writeContract({
            address: CONTRACTS.stableVault,
            abi: STABLE_VAULT_ABI,
            functionName: 'setDemoPrice',
            args: [parseUnits(String(price), 18)],
            account: address,
            chain: walletClient.chain,
        })
        await publicClient.waitForTransactionReceipt({ hash })
        await refresh()
    }, [address, publicClient, refresh, walletClient])

    useEffect(() => {
        void refresh()
        void loadBackend()
    }, [refresh, loadBackend])

    useEffect(() => {
        if (!isConnected) {
            setData(defaultPosition)
            setOwnerAddress(null)
        }
    }, [isConnected])

    return (
        <ContractContext.Provider
            value={{
                data,
                ethPrice,
                refresh,
                performAction,
                setDemoPrice,
                setDemoMode,
                isOwner,
                protocolMetrics,
                backendHealthy,
                contractsReady,
                mcrPercent,
            }}
        >
            {children}
        </ContractContext.Provider>
    )
}

export const useContract = () => {
    const context = useContext(ContractContext)
    if (!context) throw new Error('useContract must be used within a ContractProvider')
    return context
}
