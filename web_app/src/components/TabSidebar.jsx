import React from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { authService } from '../services/api'
import './TabSidebar.css'

const NAV_LINKS = [
  { to: '/',           icon: '📊', label: 'Dashboard' },
  { to: '/persons',    icon: '👥', label: 'Athletes' },
  { to: '/sessions',   icon: '📝', label: 'Sessions' },
  { to: '/analysis',   icon: '📈', label: 'Analysis' },
  { to: '/recordings', icon: '📹', label: 'Recordings' },
  { to: '/settings',   icon: '⚙️',  label: 'Settings' },
]

const TabSidebar = () => {
  const navigate = useNavigate()
  const location = useLocation()

  const isActive = (path) =>
    path === '/'
      ? location.pathname === '/'
      : location.pathname.startsWith(path)

  const handleLogout = () => {
    authService.logout()
    navigate('/login')
  }

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="tab-sidebar">
        <div className="sidebar-content">
          <div className="sidebar-logo">
            <h2>Linglong</h2>
            <p className="logo-subtitle">HR Monitor</p>
          </div>

          <nav className="sidebar-tabs">
            {NAV_LINKS.map(({ to, icon, label }) => (
              <Link
                key={to}
                to={to}
                className={`tab-link ${isActive(to) ? 'active' : ''}`}
              >
                <span className="tab-icon">{icon}</span>
                <span className="tab-label">{label}</span>
              </Link>
            ))}
          </nav>

          <div className="sidebar-footer">
            <button
              className="secondary-link"
              style={{ background: 'none', border: 'none', cursor: 'pointer', width: '100%', textAlign: 'left' }}
              onClick={handleLogout}
            >
              <span className="tab-icon">🚪</span>
              <span>Logout</span>
            </button>
          </div>
        </div>
      </aside>

      {/* Mobile bottom nav — show only 5 most important */}
      <nav className="mobile-nav">
        {NAV_LINKS.slice(0, 5).map(({ to, icon, label }) => (
          <Link
            key={to}
            to={to}
            className={`mobile-nav-link ${isActive(to) ? 'active' : ''}`}
          >
            <span className="tab-icon">{icon}</span>
            <span>{label}</span>
          </Link>
        ))}
      </nav>
    </>
  )
}

export default TabSidebar
