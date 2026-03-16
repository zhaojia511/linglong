import React from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { authService } from '../services/api'
import './TabSidebar.css'

const TabSidebar = () => {
  const navigate = useNavigate()
  const location = useLocation()

  const isActive = (path) => {
    return location.pathname === path || location.pathname.startsWith(path + '/')
  }

  const handleLogout = () => {
    authService.logout()
    navigate('/login')
  }

  return (
    <aside className="tab-sidebar">
      <div className="sidebar-content">
        <div className="sidebar-logo">
          <h2>Linglong</h2>
          <p className="logo-subtitle">HR Monitor</p>
        </div>
        
        <nav className="sidebar-tabs">
          <Link 
            to="/" 
            className={`tab-link ${isActive('/') ? 'active' : ''}`}
          >
            <span className="tab-icon">📊</span>
            <span className="tab-label">Dashboard</span>
          </Link>
          
          <Link 
            to="/persons" 
            className={`tab-link ${isActive('/persons') ? 'active' : ''}`}
          >
            <span className="tab-icon">👥</span>
            <span className="tab-label">People Management</span>
          </Link>
          
          <Link 
            to="/analysis" 
            className={`tab-link ${isActive('/analysis') ? 'active' : ''}`}
          >
            <span className="tab-icon">📈</span>
            <span className="tab-label">History</span>
          </Link>
        </nav>

        <div className="sidebar-footer">
          <Link to="/recordings" className="secondary-link">
            📹 Recordings
          </Link>
          <Link to="/sessions" className="secondary-link">
            📝 Sessions
          </Link>
        </div>
      </div>
    </aside>
  )
}

export default TabSidebar
