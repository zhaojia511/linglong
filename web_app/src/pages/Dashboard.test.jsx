import React from 'react'
import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import Dashboard from './Dashboard'

const queryClient = new QueryClient()

describe('Dashboard', () => {
  it('renders loading state', () => {
    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <Dashboard />
        </MemoryRouter>
      </QueryClientProvider>
    )
    expect(screen.getByText(/Loading/i)).toBeInTheDocument()
  })
})
