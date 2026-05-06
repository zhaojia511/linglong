import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { sessionService } from '../services/api'
import { formatDateGMT8, formatDateTimeGMT8 } from '../lib/dateTime'

function exportSessionsToCSV(sessions) {
  const headers = ['Title', 'Type', 'Date', 'Duration (min)', 'Avg HR (bpm)', 'Max HR (bpm)', 'Calories (kcal)', 'Distance (m)']
  const rows = sessions.map(s => [
    `"${(s.title || '').replace(/"/g, '""')}"`,
    s.trainingType || '',
    s.startTime ? formatDateGMT8(s.startTime) : '',
    s.duration ? Math.round(s.duration / 60) : '',
    s.avgHeartRate || '',
    s.maxHeartRate || '',
    s.calories ? Math.round(s.calories) : '',
    s.distance || '',
  ])
  const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `sessions-${new Date().toISOString().split('T')[0]}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const PAGE_SIZE = 20

function Sessions() {
  const [sessions, setSessions] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [filter, setFilter] = useState({
    startDate: '',
    endDate: '',
  })
  const [page, setPage] = useState(0)
  const [total, setTotal] = useState(0)

  useEffect(() => {
    setPage(0)
  }, [filter])

  useEffect(() => {
    loadSessions()
  }, [filter, page])

  const loadSessions = async () => {
    setLoading(true)
    setError('')
    try {
      const data = await sessionService.getSessions({ ...filter, limit: PAGE_SIZE, offset: page * PAGE_SIZE })
      setSessions(data.data ?? [])
      setTotal(data.count != null ? data.count : (data.data ?? []).length)
    } catch (error) {
      console.error('Error loading sessions:', error)
      setError('Failed to load sessions. Check your connection and try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this session?')) {
      try {
        await sessionService.deleteSession(id)
        setSessions(sessions.filter(s => s.id !== id))
      } catch (error) {
        console.error('Error deleting session:', error)
        alert('Failed to delete session')
      }
    }
  }

  const formatDuration = (seconds) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    if (hours > 0) {
      return `${hours}h ${minutes}m`
    }
    return `${minutes}m`
  }

  return (
    <div>
      <div className="header">
        <div className="container">
          <h1>Training Sessions</h1>
          <div className="nav">
            <Link to="/">Dashboard</Link>
            <Link to="/sessions" className="active">All Sessions</Link>
          </div>
        </div>
      </div>

      <div className="container">
        <div className="card">
          <h2>Filter Sessions</h2>
          <div style={{ display: 'flex', gap: '20px', marginTop: '20px' }}>
            <div className="form-group">
              <label>Start Date</label>
              <input
                type="date"
                value={filter.startDate}
                onChange={(e) => setFilter({ ...filter, startDate: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>End Date</label>
              <input
                type="date"
                value={filter.endDate}
                onChange={(e) => setFilter({ ...filter, endDate: e.target.value })}
              />
            </div>
          </div>
        </div>

        {error && (
          <div className="card" style={{background:'#fff3cd', border:'1px solid #ffc107', padding:'15px', marginBottom:'20px'}}>
            <strong>Error:</strong> {error}
            <button onClick={loadSessions} className="btn btn-primary" style={{marginLeft:'15px'}}>Retry</button>
          </div>
        )}

        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h2>All Training Sessions ({sessions.length})</h2>
            {sessions.length > 0 && (
              <button
                onClick={() => exportSessionsToCSV(sessions)}
                className="btn"
                style={{ background: '#28a745', color: 'white' }}
              >
                Export CSV
              </button>
            )}
          </div>
          {loading ? (
            <p>Loading...</p>
          ) : sessions.length === 0 ? (
            <p>No training sessions found.</p>
          ) : (
            <ul className="session-list">
              {sessions.map((session) => (
                <li key={session.id} className="session-item">
                  <div style={{ flex: 1 }}>
                    <strong>{session.title}</strong>
                    <div style={{ fontSize: '14px', color: '#666', marginTop: '5px' }}>
                      <div>{formatDateTimeGMT8(session.startTime, { seconds: true })}</div>
                      <div>
                        Duration: {formatDuration(session.duration)} • Type: {session.trainingType}
                      </div>
                      {session.avgHeartRate && (
                        <div>
                          Avg HR: {session.avgHeartRate} bpm • Max HR: {session.maxHeartRate} bpm
                        </div>
                      )}
                      {session.calories && (
                        <div>Calories: {Math.round(session.calories)} kcal</div>
                      )}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: '10px' }}>
                    <Link to={`/sessions/${session.id}`} className="btn btn-primary">
                      View Details
                    </Link>
                    <button
                      onClick={() => handleDelete(session.id)}
                      className="btn"
                      style={{ background: '#dc3545', color: 'white' }}
                    >
                      Delete
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
          <div style={{ display: 'flex', justifyContent: 'center', gap: '10px', marginTop: '16px' }}>
            <button className="btn" onClick={() => setPage(p => p - 1)} disabled={page === 0}>Previous</button>
            <span style={{ padding: '8px 16px' }}>Page {page + 1}</span>
            <button className="btn btn-primary" onClick={() => setPage(p => p + 1)} disabled={sessions.length < PAGE_SIZE}>Next</button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Sessions
