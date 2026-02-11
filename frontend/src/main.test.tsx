import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ReactNode } from 'react'

const renderMock = vi.fn()
const createRootMock = vi.fn(() => ({ render: renderMock }))

vi.mock('react-dom/client', () => ({
  default: { createRoot: createRootMock },
  createRoot: createRootMock,
}))

vi.mock('./App.tsx', () => ({
  default: () => <div>app-mock</div>,
}))

vi.mock('./wagmi.ts', () => ({
  config: { test: true },
}))

vi.mock('./context/ContractContext.tsx', () => ({
  ContractProvider: ({ children }: { children: ReactNode }) => <>{children}</>,
}))

describe('main.tsx bootstrap', () => {
  beforeEach(() => {
    vi.resetModules()
    renderMock.mockClear()
    createRootMock.mockClear()
    document.body.innerHTML = '<div id="root"></div>'
  })

  it('creates root and renders app tree', async () => {
    await import('./main.tsx')

    expect(createRootMock).toHaveBeenCalledTimes(1)
    expect(createRootMock).toHaveBeenCalledWith(document.getElementById('root'))
    expect(renderMock).toHaveBeenCalledTimes(1)
  })
})
