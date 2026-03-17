import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../services/supabaseClient'
import './Settings.css'

const PLATFORMS = ['ios', 'android']

function AppVersionManager() {
  const [versions, setVersions] = useState({ ios: null, android: null })
  const [editing, setEditing] = useState(null) // 'ios' | 'android' | null
  const [form, setForm] = useState({ version: '', buildNumber: '', releaseNotes: '', minSupportedVersion: '' })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)

  useEffect(() => { fetchVersions() }, [])

  async function fetchVersions() {
    const { data } = await supabase.from('app_versions').select('*')
    if (data) {
      const map = {}
      data.forEach(row => { map[row.platform] = row })
      setVersions(prev => ({ ...prev, ...map }))
    }
  }

  function startEdit(platform) {
    const v = versions[platform]
    setForm({
      version: v?.version ?? '1.0.0',
      buildNumber: String(v?.build_number ?? 1),
      releaseNotes: v?.release_notes ?? '',
      minSupportedVersion: v?.min_supported_version ?? '1.0.0',
    })
    setEditing(platform)
  }

  async function save() {
    setSaving(true)
    setMessage(null)
    const { error } = await supabase.from('app_versions').upsert({
      platform: editing,
      version: form.version,
      build_number: parseInt(form.buildNumber) || 1,
      release_notes: form.releaseNotes,
      min_supported_version: form.minSupportedVersion,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'platform' })
    setSaving(false)
    if (error) {
      setMessage({ type: 'error', text: error.message })
    } else {
      setMessage({ type: 'success', text: `${editing} version saved` })
      setEditing(null)
      fetchVersions()
    }
  }

  return (
    <div className="settings-card">
      <h2 className="settings-section">📱 App Version Management</h2>
      <p style={{ fontSize: 13, color: '#666', marginBottom: 12 }}>
        Set the latest published version for each platform. The mobile app checks this on startup
        and notifies users when an update is available.
      </p>

      {message && (
        <div className={`${message.type === 'error' ? 'error-message' : 'success-message'}`}
          style={{ marginBottom: 12 }}>
          {message.text}
        </div>
      )}

      {PLATFORMS.map(platform => {
        const v = versions[platform]
        return (
          <div key={platform} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10, padding: '10px 0', borderBottom: '1px solid #eee' }}>
            <div style={{ flex: 1 }}>
              <strong style={{ textTransform: 'capitalize' }}>{platform}</strong>
              {v ? (
                <span style={{ marginLeft: 12, fontSize: 13, color: '#555' }}>
                  v{v.version} (build {v.build_number}) · min {v.min_supported_version}
                </span>
              ) : (
                <span style={{ marginLeft: 12, fontSize: 12, color: '#999' }}>not set</span>
              )}
            </div>
            <button className="btn btn-secondary" style={{ padding: '4px 12px', fontSize: 13 }}
              onClick={() => startEdit(platform)}>
              Edit
            </button>
          </div>
        )
      })}

      {editing && (
        <div style={{ marginTop: 16, padding: 16, background: '#f9f9f9', borderRadius: 8, border: '1px solid #ddd' }}>
          <h3 style={{ margin: '0 0 12px', textTransform: 'capitalize' }}>{editing} — Edit Version</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <label>
              <span style={{ fontSize: 12, color: '#666' }}>Latest version (semver)</span>
              <input className="setting-input" value={form.version}
                onChange={e => setForm(f => ({ ...f, version: e.target.value }))}
                placeholder="1.0.1" style={{ display: 'block', width: '100%', marginTop: 4 }} />
            </label>
            <label>
              <span style={{ fontSize: 12, color: '#666' }}>Build number</span>
              <input className="setting-input" type="number" value={form.buildNumber}
                onChange={e => setForm(f => ({ ...f, buildNumber: e.target.value }))}
                placeholder="2" style={{ display: 'block', width: '100%', marginTop: 4 }} />
            </label>
            <label>
              <span style={{ fontSize: 12, color: '#666' }}>Min supported version (forced update)</span>
              <input className="setting-input" value={form.minSupportedVersion}
                onChange={e => setForm(f => ({ ...f, minSupportedVersion: e.target.value }))}
                placeholder="1.0.0" style={{ display: 'block', width: '100%', marginTop: 4 }} />
            </label>
          </div>
          <label style={{ display: 'block', marginTop: 12 }}>
            <span style={{ fontSize: 12, color: '#666' }}>Release notes</span>
            <textarea className="setting-input" rows={3} value={form.releaseNotes}
              onChange={e => setForm(f => ({ ...f, releaseNotes: e.target.value }))}
              placeholder="What's new in this version..."
              style={{ display: 'block', width: '100%', marginTop: 4, resize: 'vertical' }} />
          </label>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button className="btn btn-primary" onClick={save} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </button>
            <button className="btn btn-secondary" onClick={() => setEditing(null)}>Cancel</button>
          </div>
        </div>
      )}
    </div>
  )
}

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

      <AppVersionManager />
    </div>
  )
}

export default Settings
