import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { sessionService } from '../services/api'

function Sessions() {
  const [sessions, setSessions] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState({
    startDate: '',
    endDate: '',
  })

  useEffect(() => {
    loadSessions()
  }, [filter])

  const loadSessions = async () => {
    try {
      const data = await sessionService.getSessions(filter)
      setSessions(data.data)
    } catch (error) {
      console.error('Error loading sessions:', error)
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

        <div className="card">
          <h2>All Training Sessions ({sessions.length})</h2>
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
                      <div>{new Date(session.startTime).toLocaleString()}</div>
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
        </div>
      </div>
    </div>
  )
}

export default Sessions
