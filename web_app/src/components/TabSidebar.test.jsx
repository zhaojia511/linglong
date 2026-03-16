import React from 'react'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import TabSidebar from './TabSidebar'

describe('TabSidebar', () => {
  it('renders all main tabs', () => {
    render(
      <MemoryRouter>
        <TabSidebar />
      </MemoryRouter>
    )
    expect(screen.getByText(/Dashboard/i)).toBeInTheDocument()
    expect(screen.getByText(/People Management/i)).toBeInTheDocument()
    expect(screen.getByText(/History/i)).toBeInTheDocument()
  })
})
