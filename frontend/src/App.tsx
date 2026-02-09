import { Layout, Row, Col } from 'antd'
const { Content, Footer } = Layout
import { Header } from './components/Header'
import { Dashboard } from './components/Dashboard'
import { ActionPanel } from './components/ActionPanel'
import { LiquidationDemo } from './components/LiquidationDemo'
import './App.css'

function App() {
  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header />
      <Content style={{ padding: '24px 48px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
          <Dashboard />
          <Row gutter={24}>
            <Col span={12}>
              <ActionPanel />
            </Col>
            <Col span={12}>
              <LiquidationDemo />
            </Col>
          </Row>
        </div>
      </Content>
      <Footer style={{ textAlign: 'center' }}>
        StableVault ©{new Date().getFullYear()} Decentralized Stability
      </Footer>
    </Layout>
  )
}

export default App
