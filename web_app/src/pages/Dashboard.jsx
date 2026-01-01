import React, { useState, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { sessionService, authService } from '../services/api'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

function Dashboard() {
  const [stats, setStats] = useState(null)
  const [recentSessions, setRecentSessions] = useState([])
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()

  useEffect(() => {
    loadDashboardData()
  }, [])

  const loadDashboardData = async () => {
    try {
      const [statsData, sessionsData] = await Promise.all([
        sessionService.getStats(),
        sessionService.getSessions({ limit: 5 })
      ])
      setStats(statsData.data)
      setRecentSessions(sessionsData.data)
    } catch (error) {
      console.error('Error loading dashboard:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleLogout = () => {
    authService.logout()
    navigate('/login')
  }

  const formatDuration = (seconds) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    if (hours > 0) {
      return `${hours}h ${minutes}m`
    }
    return `${minutes}m`
  }

  if (loading) {
    return <div className="container">Loading...</div>
  }

  return (
    <div>
      <div className="header">
        <div className="container">
          <h1>Linglong HR Monitor Dashboard</h1>
          <div className="nav">
            <Link to="/" className="active">Dashboard</Link>
            <Link to="/sessions">All Sessions</Link>
            <button onClick={handleLogout} className="btn btn-primary">Logout</button>
          </div>
        </div>
      </div>

      <div className="container">
        {stats && (
          <>
            <div className="stats-grid">
              <div className="stat-card">
                <div className="stat-label">Total Sessions</div>
                <div className="stat-value">{stats.totalSessions}</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Total Duration</div>
                <div className="stat-value">{formatDuration(stats.totalDuration)}</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Avg Heart Rate</div>
                <div className="stat-value">{stats.avgHeartRate}</div>
                <div className="stat-label">bpm</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Total Calories</div>
                <div className="stat-value">{Math.round(stats.totalCalories)}</div>
                <div className="stat-label">kcal</div>
              </div>
            </div>

            <div className="card">
              <h2>Training Types Distribution</h2>
              <div style={{ marginTop: '20px' }}>
                {Object.entries(stats.trainingTypes).map(([type, count]) => (
                  <div key={type} style={{ marginBottom: '10px' }}>
                    <strong>{type}:</strong> {count} sessions
                  </div>
                ))}
              </div>
            </div>
          </>
        )}

        <div className="card">
          <h2>Recent Training Sessions</h2>
          {recentSessions.length === 0 ? (
            <p>No training sessions yet.</p>
          ) : (
            <ul className="session-list">
              {recentSessions.map((session) => (
                <li key={session.id} className="session-item">
                  <div>
                    <strong>{session.title}</strong>
                    <div style={{ fontSize: '14px', color: '#666', marginTop: '5px' }}>
                      {new Date(session.startTime).toLocaleDateString()} • {formatDuration(session.duration)}
                      {session.avgHeartRate && ` • Avg HR: ${session.avgHeartRate} bpm`}
                    </div>
                  </div>
                  <Link to={`/sessions/${session.id}`} className="btn btn-primary">
                    View
                  </Link>
                </li>
              ))}
            </ul>
          )}
          <div style={{ marginTop: '20px' }}>
            <Link to="/sessions" className="btn btn-primary">View All Sessions</Link>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Dashboard
