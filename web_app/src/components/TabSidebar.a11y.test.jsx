import React from 'react'
import { render } from '@testing-library/react'
import { axe, toHaveNoViolations } from 'jest-axe'
import { MemoryRouter } from 'react-router-dom'
import TabSidebar from './TabSidebar'

expect.extend(toHaveNoViolations)

describe('TabSidebar accessibility', () => {
  it('should have no a11y violations', async () => {
    const { container } = render(
      <MemoryRouter>
        <TabSidebar />
      </MemoryRouter>
    )
    const results = await axe(container)
    expect(results).toHaveNoViolations()
  })
})
