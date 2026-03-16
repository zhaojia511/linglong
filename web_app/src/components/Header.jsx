import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { authService } from '../services/api'
import './Header.css'

const Header = () => {
  const navigate = useNavigate()
  const [showUserMenu, setShowUserMenu] = useState(false)
  const [user, setUser] = useState(null)

  React.useEffect(() => {
    // Load user info from localStorage or API
    const userData = localStorage.getItem('user')
    if (userData) {
      setUser(JSON.parse(userData))
    }
  }, [])

  const handleLogout = () => {
    authService.logout()
    setShowUserMenu(false)
    navigate('/login')
  }

  const handleSettings = () => {
    // TODO: Implement settings page
    setShowUserMenu(false)
    navigate('/settings')
  }

  const userInitials = user?.email ? user.email.charAt(0).toUpperCase() : 'U'

  return (
    <header className="top-header">
      <div className="header-spacer"></div>
      <div className="header-right">
        <div className="user-menu-container">
          <button 
            className="user-avatar"
            onClick={() => setShowUserMenu(!showUserMenu)}
            title={user?.email || 'User'}
          >
            {userInitials}
          </button>
          
          {showUserMenu && (
            <div className="user-dropdown">
              <div className="user-info">
                <p className="user-email">{user?.email || 'User'}</p>
              </div>
              <hr />
              <button 
                className="dropdown-item"
                onClick={handleSettings}
              >
                <span className="icon">⚙️</span>
                Settings
              </button>
              <button 
                className="dropdown-item logout"
                onClick={handleLogout}
              >
                <span className="icon">🚪</span>
                Logout
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}

export default Header
