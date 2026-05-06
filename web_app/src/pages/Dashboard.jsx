
import React from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { authService } from '../services/api'
import { useDashboardData } from './hooks/useDashboardData'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { formatDateGMT8 } from '../lib/dateTime'


function Dashboard() {
  const navigate = useNavigate()
  const { statsQuery, sessionsQuery } = useDashboardData()

  // Backend wraps all responses as { success: true, data: ... }
  // statsQuery.data is the full response object; .data is the actual stats
  const stats = statsQuery.data?.data ?? statsQuery.data

  // sessionsQuery.data is { success, count, total, data: [...] }
  // so the array is at .data.data
  const recentSessions = sessionsQuery.data?.data ?? []

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

  if (statsQuery.isLoading || sessionsQuery.isLoading) {
    return <div className="container">Loading...</div>
  }

  if (statsQuery.isError || sessionsQuery.isError) {
    return (
      <div>
        <div className="container">
          <div className="error" style={{padding: '20px', fontSize: '16px'}}>
            <strong>Error Loading Dashboard:</strong>
            <p>{statsQuery.error?.message || sessionsQuery.error?.message}</p>
            <p style={{fontSize: '12px', color: '#666'}}>
              Check browser console (F12) for full error details.
            </p>
            <button onClick={() => { statsQuery.refetch(); sessionsQuery.refetch(); }} className="btn btn-primary">Retry</button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div>
      <div className="header">
        <div className="container">
          <h1>Linglong HR Monitor Dashboard</h1>
          <div className="nav">
            <Link to="/" className="active">Dashboard</Link>
            <Link to="/persons">Persons</Link>
            <Link to="/analysis">Analysis</Link>
            <Link to="/sessions">All Sessions</Link>
            <button onClick={handleLogout} className="btn btn-primary">Logout</button>
          </div>
        </div>
      </div>

      <div className="container">
        {/* Quick Actions */}
        <div className="card" style={{ marginBottom: '30px' }}>
          <h2>Quick Actions</h2>
          <div style={{ display: 'flex', gap: '15px', flexWrap: 'wrap', marginTop: '15px' }}>
            <Link to="/persons" className="btn btn-primary">Manage Persons</Link>
            <Link to="/analysis" className="btn btn-primary">View Analysis</Link>
            <Link to="/sessions" className="btn btn-primary">All Sessions</Link>
          </div>
        </div>

        {statsQuery.data && (
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

            {stats.trainingTypes && Object.keys(stats.trainingTypes).length > 0 && (
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
            )}
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
                      {formatDateGMT8(session.startTime)} • {formatDuration(session.duration)}
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
