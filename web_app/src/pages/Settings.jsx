import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import './Settings.css'

function Settings() {
  const navigate = useNavigate()
  const [settings, setSettings] = useState({
    theme: 'light',
    notifications: true,
    emailNotifications: true,
    autoRefresh: true,
    autoRefreshInterval: 30
  })
  const [saved, setSaved] = useState(false)

  const handleSettingChange = (key, value) => {
    setSettings(prev => ({
      ...prev,
      [key]: value
    }))
    setSaved(false)
  }

  const handleSave = () => {
    // Save settings to localStorage
    localStorage.setItem('userSettings', JSON.stringify(settings))
    setSaved(true)
    setTimeout(() => setSaved(false), 3000)
  }

  return (
    <div className="settings-container">
      <h1 className="settings-title">Settings</h1>
      
      <div className="settings-card">
        <h2 className="settings-section">Display</h2>
        
        <div className="setting-item">
          <label>Theme</label>
          <select 
            value={settings.theme}
            onChange={(e) => handleSettingChange('theme', e.target.value)}
            className="setting-select"
          >
            <option value="light">Light</option>
            <option value="dark">Dark</option>
            <option value="auto">Auto</option>
          </select>
        </div>
      </div>

      <div className="settings-card">
        <h2 className="settings-section">Notifications</h2>
        
        <div className="setting-item">
          <label className="setting-label-checkbox">
            <input 
              type="checkbox" 
              checked={settings.notifications}
              onChange={(e) => handleSettingChange('notifications', e.target.checked)}
            />
            <span>Enable Desktop Notifications</span>
          </label>
        </div>

        <div className="setting-item">
          <label className="setting-label-checkbox">
            <input 
              type="checkbox" 
              checked={settings.emailNotifications}
              onChange={(e) => handleSettingChange('emailNotifications', e.target.checked)}
            />
            <span>Enable Email Notifications</span>
          </label>
        </div>
      </div>

      <div className="settings-card">
        <h2 className="settings-section">Auto Refresh</h2>
        
        <div className="setting-item">
          <label className="setting-label-checkbox">
            <input 
              type="checkbox" 
              checked={settings.autoRefresh}
              onChange={(e) => handleSettingChange('autoRefresh', e.target.checked)}
            />
            <span>Enable Auto Refresh</span>
          </label>
        </div>

        {settings.autoRefresh && (
          <div className="setting-item">
            <label>Refresh Interval (seconds)</label>
            <input 
              type="number" 
              min="10" 
              max="300"
              value={settings.autoRefreshInterval}
              onChange={(e) => handleSettingChange('autoRefreshInterval', parseInt(e.target.value))}
              className="setting-input"
            />
          </div>
        )}
      </div>

      <div className="settings-actions">
        <button 
          onClick={handleSave}
          className="btn btn-primary"
        >
          💾 Save Settings
        </button>
        <button 
          onClick={() => navigate('/')}
          className="btn btn-secondary"
        >
          ← Back
        </button>
      </div>

      {saved && (
        <div className="success-message">
          ✓ Settings saved successfully
        </div>
      )}
    </div>
  )
}

export default Settings
