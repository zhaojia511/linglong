import React, { useState, useEffect } from 'react'
import { v4 as uuidv4 } from 'uuid'
import { sessionService, personService } from '../services/api'

const inputStyle = { width: '100%', padding: '8px 10px', border: '1px solid #ddd', borderRadius: 4, fontSize: 14, boxSizing: 'border-box' }
const labelStyle = { display: 'block', marginBottom: 4, fontWeight: 500, fontSize: 14 }
const thStyle = { textAlign: 'left', padding: '10px 12px', borderBottom: '2px solid #eee', fontSize: 13, color: '#666' }
const tdStyle = { padding: '10px 12px', borderBottom: '1px solid #eee', fontSize: 14 }

const RecordingManagement = () => {
  const [sessions, setSessions] = useState([])
  const [persons, setPersons] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editingSession, setEditingSession] = useState(null)
  const [formData, setFormData] = useState({
    personId: '',
    title: '',
    trainingType: '',
    startTime: '',
    endTime: '',
    duration: '',
    distance: '',
    calories: '',
    avgHeartRate: '',
    maxHeartRate: '',
    minHeartRate: '',
    notes: ''
  })

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    try {
      setLoading(true)
      const [sessionsResponse, personsResponse] = await Promise.all([
        sessionService.getSessions(),
        personService.getPersons()
      ])
      setSessions(sessionsResponse.data || [])
      setPersons(personsResponse.data || [])
    } catch (error) {
      console.error('Error loading data:', error)
      setError('Failed to load data')
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!formData.personId) { setError('Please select a person'); return }
    if (!formData.title.trim()) { setError('Title is required'); return }
    if (!formData.trainingType) { setError('Training type is required'); return }
    if (!formData.startTime) { setError('Start time is required'); return }
    try {
      const data = {
        ...formData,
        ...(formData.duration !== '' && formData.duration != null ? { duration: parseInt(formData.duration) } : {}),
        ...(formData.distance !== '' && formData.distance != null ? { distance: parseFloat(formData.distance) } : {}),
        ...(formData.calories !== '' && formData.calories != null ? { calories: parseFloat(formData.calories) } : {}),
        ...(formData.avgHeartRate !== '' && formData.avgHeartRate != null ? { avgHeartRate: parseInt(formData.avgHeartRate) } : {}),
        ...(formData.maxHeartRate !== '' && formData.maxHeartRate != null ? { maxHeartRate: parseInt(formData.maxHeartRate) } : {}),
        ...(formData.minHeartRate !== '' && formData.minHeartRate != null ? { minHeartRate: parseInt(formData.minHeartRate) } : {}),
        startTime: new Date(formData.startTime).toISOString(),
        endTime: formData.endTime ? new Date(formData.endTime).toISOString() : null
      }

      if (editingSession) {
        await sessionService.upsertSession({ ...data, id: editingSession.id })
      } else {
        await sessionService.upsertSession({ ...data, id: uuidv4() })
      }

      await loadData()
      setShowForm(false)
      setEditingSession(null)
      resetForm()
    } catch (error) {
      console.error('Error saving session:', error)
      setError('Failed to save session')
    }
  }

  const handleEdit = (session) => {
    setEditingSession(session)
    setFormData({
      personId: session.personId || '',
      title: session.title || '',
      trainingType: session.trainingType || '',
      startTime: session.startTime ? new Date(session.startTime).toISOString().slice(0, 16) : '',
      endTime: session.endTime ? new Date(session.endTime).toISOString().slice(0, 16) : '',
      duration: session.duration?.toString() || '',
      distance: session.distance?.toString() || '',
      calories: session.calories?.toString() || '',
      avgHeartRate: session.avgHeartRate?.toString() || '',
      maxHeartRate: session.maxHeartRate?.toString() || '',
      minHeartRate: session.minHeartRate?.toString() || '',
      notes: session.notes || ''
    })
    setShowForm(true)
  }

  const handleDelete = async (sessionId) => {
    if (!window.confirm('Are you sure you want to delete this session?')) return

    try {
      await sessionService.deleteSession(sessionId)
      setSessions(sessions.filter(s => s.id !== sessionId))
    } catch (error) {
      console.error('Error deleting session:', error)
      setError('Failed to delete session')
    }
  }

  const resetForm = () => {
    setFormData({
      personId: '',
      title: '',
      trainingType: '',
      startTime: '',
      endTime: '',
      duration: '',
      distance: '',
      calories: '',
      avgHeartRate: '',
      maxHeartRate: '',
      minHeartRate: '',
      notes: ''
    })
  }

  const handleCancel = () => {
    setShowForm(false)
    setEditingSession(null)
    resetForm()
  }

  const getPersonName = (personId) => {
    const person = persons.find(p => p.id === personId)
    return person ? person.name : 'Unknown'
  }

  const formatDuration = (seconds) => {
    if (!seconds) return '-'
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const formatDate = (dateString) => {
    if (!dateString) return '-'
    return new Date(dateString).toLocaleDateString() + ' ' + new Date(dateString).toLocaleTimeString()
  }

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: 40 }}>Loading...</div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h1 style={{ margin: 0 }}>Recording Management</h1>
        <button className="btn btn-primary" onClick={() => setShowForm(true)}>Add Session</button>
      </div>

      {error && (
        <div className="error">{error}</div>
      )}

      {/* Session Form */}
      {showForm && (
        <div className="card" style={{ marginBottom: 24 }}>
          <h2 style={{ marginTop: 0, marginBottom: 16 }}>
            {editingSession ? 'Edit Session' : 'Add New Session'}
          </h2>
          <form onSubmit={handleSubmit}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
              <div>
                <label style={labelStyle}>Person *</label>
                <select
                  value={formData.personId}
                  onChange={(e) => setFormData({...formData, personId: e.target.value})}
                  style={inputStyle}
                >
                  <option value="">Select Person</option>
                  {persons.map(person => (
                    <option key={person.id} value={person.id}>{person.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label style={labelStyle}>Session Title *</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({...formData, title: e.target.value})}
                  style={inputStyle}
                  placeholder="e.g., Morning Run, Evening Cycling"
                />
              </div>

              <div>
                <label style={labelStyle}>Training Type *</label>
                <select
                  value={formData.trainingType}
                  onChange={(e) => setFormData({...formData, trainingType: e.target.value})}
                  style={inputStyle}
                >
                  <option value="">Select Type</option>
                  <option value="running">Running</option>
                  <option value="cycling">Cycling</option>
                  <option value="swimming">Swimming</option>
                  <option value="gym">Gym / Weights</option>
                  <option value="general">General / Yoga</option>
                  <option value="other">Other</option>
                </select>
              </div>

              <div>
                <label style={labelStyle}>Start Time *</label>
                <input
                  type="datetime-local"
                  value={formData.startTime}
                  onChange={(e) => setFormData({...formData, startTime: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>End Time</label>
                <input
                  type="datetime-local"
                  value={formData.endTime}
                  onChange={(e) => setFormData({...formData, endTime: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Duration (seconds)</label>
                <input
                  type="number"
                  value={formData.duration}
                  onChange={(e) => setFormData({...formData, duration: e.target.value})}
                  style={inputStyle}
                  placeholder="3600 for 1 hour"
                />
              </div>

              <div>
                <label style={labelStyle}>Distance (meters)</label>
                <input
                  type="number"
                  step="0.1"
                  value={formData.distance}
                  onChange={(e) => setFormData({...formData, distance: e.target.value})}
                  style={inputStyle}
                  placeholder="5000 for 5km"
                />
              </div>

              <div>
                <label style={labelStyle}>Calories Burned</label>
                <input
                  type="number"
                  step="0.1"
                  value={formData.calories}
                  onChange={(e) => setFormData({...formData, calories: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Avg Heart Rate (bpm)</label>
                <input
                  type="number"
                  value={formData.avgHeartRate}
                  onChange={(e) => setFormData({...formData, avgHeartRate: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Max Heart Rate (bpm)</label>
                <input
                  type="number"
                  value={formData.maxHeartRate}
                  onChange={(e) => setFormData({...formData, maxHeartRate: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Min Heart Rate (bpm)</label>
                <input
                  type="number"
                  value={formData.minHeartRate}
                  onChange={(e) => setFormData({...formData, minHeartRate: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div style={{ gridColumn: 'span 2' }}>
                <label style={labelStyle}>Notes</label>
                <textarea
                  value={formData.notes}
                  onChange={(e) => setFormData({...formData, notes: e.target.value})}
                  rows={3}
                  style={{ ...inputStyle, resize: 'vertical' }}
                  placeholder="Additional notes about the session..."
                />
              </div>

              <div style={{ gridColumn: 'span 2', display: 'flex', gap: 12, marginTop: 4 }}>
                <button type="submit" className="btn btn-primary">
                  {editingSession ? 'Update Session' : 'Add Session'}
                </button>
                <button type="button" className="btn" style={{ background: '#6c757d', color: 'white' }} onClick={handleCancel}>
                  Cancel
                </button>
              </div>
            </div>
          </form>
        </div>
      )}

      {/* Sessions List */}
      <div className="card" style={{ padding: 0 }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid #eee' }}>
          <h2 style={{ margin: 0 }}>Training Sessions ({sessions.length})</h2>
        </div>

        {sessions.length === 0 ? (
          <p style={{ textAlign: 'center', color: '#999', padding: 40 }}>No sessions found. Add your first training session to get started.</p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={thStyle}>Title</th>
                  <th style={thStyle}>Type</th>
                  <th style={thStyle}>Date &amp; Time</th>
                  <th style={thStyle}>Duration</th>
                  <th style={thStyle}>Distance</th>
                  <th style={thStyle}>Avg HR</th>
                  <th style={thStyle}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((session) => (
                  <tr key={session.id}>
                    <td style={tdStyle}>{session.title || 'Untitled Session'}</td>
                    <td style={{ ...tdStyle, textTransform: 'capitalize' }}>{session.trainingType || '-'}</td>
                    <td style={tdStyle}>{formatDate(session.startTime)}</td>
                    <td style={tdStyle}>{formatDuration(session.duration)}</td>
                    <td style={tdStyle}>{session.distance ? `${(session.distance / 1000).toFixed(2)} km` : '-'}</td>
                    <td style={tdStyle}>{session.avgHeartRate ? `${session.avgHeartRate} bpm` : '-'}</td>
                    <td style={tdStyle}>
                      <button
                        className="btn"
                        style={{ marginRight: 8, padding: '4px 10px', fontSize: 13 }}
                        onClick={() => handleEdit(session)}
                      >
                        Edit
                      </button>
                      <button
                        className="btn"
                        style={{ background: '#dc3545', color: 'white', padding: '4px 10px', fontSize: 13 }}
                        onClick={() => handleDelete(session.id)}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}

export default RecordingManagement
