import React from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { authService } from '../services/api'

const Sidebar = () => {
  const navigate = useNavigate()

  const handleLogout = () => {
    authService.logout()
    navigate('/login')
  }

  return (
    <aside className="sidebar">
      <div className="sidebar-inner">
        <h1 className="sidebar-title">Linglong HR</h1>
        <nav className="sidebar-nav">
          <Link to="/" className="nav-link">Dashboard</Link>
          <Link to="/persons" className="nav-link">Persons</Link>
          <Link to="/analysis" className="nav-link">Analysis</Link>
          <Link to="/sessions" className="nav-link">All Sessions</Link>
          <button onClick={handleLogout} className="btn btn-primary sidebar-logout">Logout</button>
        </nav>
      </div>
    </aside>
  )
}

export default Sidebar
