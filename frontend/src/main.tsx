import React from 'react'
import ReactDOM from 'react-dom/client'
import { ConfigProvider, theme } from 'antd'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App.tsx'
import { config } from './wagmi.ts'
import { ContractProvider } from './context/ContractContext.tsx'
import './index.css'

const queryClient = new QueryClient()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ContractProvider>
          <ConfigProvider
            theme={{
              algorithm: theme.darkAlgorithm,
              token: {
                colorPrimary: '#3b82f6',
              },
            }}
          >
            <App />
          </ConfigProvider>
        </ContractProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
)
