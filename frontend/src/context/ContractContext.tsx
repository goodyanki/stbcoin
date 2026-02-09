import { createContext, useContext, useState, useEffect, type ReactNode } from 'react'
import { useAccount } from 'wagmi'

export interface UserPosition {
    collateral: number // ETH
    debt: number // Stablecoin
    collateralRatio: number // %
    liquidationPrice: number
    healthFactor: 'Safe' | 'Warning' | 'Danger'
    maxLTV: number
}

interface ContractContextType {
    data: UserPosition
    ethPrice: number
    setEthPrice: (price: number) => void
    refresh: () => void
    updatePosition: (type: 'deposit' | 'mint' | 'repay' | 'withdraw', amount: number) => void
}

const ContractContext = createContext<ContractContextType | undefined>(undefined)

export function ContractProvider({ children }: { children: ReactNode }) {
    const { isConnected } = useAccount()
    const [ethPrice, setEthPrice] = useState(2500)

    // Single source of truth for user position
    const [collateral, setCollateral] = useState(0)
    const [debt, setDebt] = useState(0)

    const [data, setData] = useState<UserPosition>({
        collateral: 0,
        debt: 0,
        collateralRatio: 0,
        liquidationPrice: 0,
        healthFactor: 'Safe',
        maxLTV: 1.5
    })

    // Initial load simulation
    useEffect(() => {
        if (isConnected && collateral === 0 && debt === 0) {
            setCollateral(10.5)
            setDebt(15000)
        } else if (!isConnected) {
            setCollateral(0)
            setDebt(0)
        }
    }, [isConnected])

    // Recalculate derived data whenever state changes
    useEffect(() => {
        if (!isConnected || collateral === 0) {
            setData({
                collateral: 0,
                debt: 0,
                collateralRatio: 0,
                liquidationPrice: 0,
                healthFactor: 'Safe',
                maxLTV: 1.5
            })
            return
        }

        const cr = debt > 0 ? (collateral * ethPrice / debt) * 100 : 9999 // Infinite if no debt

        let health: 'Safe' | 'Warning' | 'Danger' = 'Safe'
        if (cr < 110) health = 'Danger'
        else if (cr < 150) health = 'Warning'

        // Liquidation Price calculation:
        // CR = (Col * Price) / Debt * 100
        // Liquidation when CR = 110
        // 110 = (Col * Price) / Debt * 100
        // 1.1 = (Col * Price) / Debt
        // Price = (1.1 * Debt) / Col
        const liqPrice = collateral > 0 ? (1.1 * debt) / collateral : 0

        setData({
            collateral,
            debt,
            collateralRatio: cr,
            liquidationPrice: liqPrice,
            healthFactor: health,
            maxLTV: 1.5
        })
    }, [isConnected, ethPrice, collateral, debt])

    const updatePosition = (type: 'deposit' | 'mint' | 'repay' | 'withdraw', amount: number) => {
        switch (type) {
            case 'deposit': setCollateral(prev => prev + amount); break;
            case 'mint': setDebt(prev => prev + amount); break;
            case 'repay': setDebt(prev => Math.max(0, prev - amount)); break;
            case 'withdraw': setCollateral(prev => Math.max(0, prev - amount)); break;
        }
    }

    return (
        <ContractContext.Provider value={{ data, ethPrice, setEthPrice, refresh: () => { }, updatePosition }}>
            {children}
        </ContractContext.Provider>
    )
}

export const useContract = () => {
    const context = useContext(ContractContext)
    if (!context) throw new Error('useContract must be used within a ContractProvider')
    return context
}
