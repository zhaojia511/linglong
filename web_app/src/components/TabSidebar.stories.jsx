import React from 'react'
import { MemoryRouter } from 'react-router-dom'
import TabSidebar from './TabSidebar'

export default {
  title: 'Components/TabSidebar',
  component: TabSidebar,
  decorators: [
    (Story) => <MemoryRouter><Story /></MemoryRouter>
  ]
}

export const Default = () => <TabSidebar />
