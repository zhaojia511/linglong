import React, { useState, useEffect } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { sessionService } from '../services/api'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { format } from 'date-fns'

function SessionDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadSession()
  }, [id])

  const loadSession = async () => {
    try {
      const data = await sessionService.getSession(id)
      setSession(data.data)
    } catch (error) {
      console.error('Error loading session:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    if (window.confirm('Are you sure you want to delete this session?')) {
      try {
        await sessionService.deleteSession(id)
        navigate('/sessions')
      } catch (error) {
        console.error('Error deleting session:', error)
        alert('Failed to delete session')
      }
    }
  }

  const formatDuration = (seconds) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    if (hours > 0) {
      return `${hours}h ${minutes}m ${secs}s`
    }
    return `${minutes}m ${secs}s`
  }

  if (loading) {
    return <div className="container">Loading...</div>
  }

  if (!session) {
    return <div className="container">Session not found</div>
  }

  // Prepare chart data - sample every 10th point if there's too much data
  const chartData = session.heartRateData
    .filter((_, index) => session.heartRateData.length > 100 ? index % 10 === 0 : true)
    .map((data, index) => ({
      time: index,
      heartRate: data.heartRate,
      timestamp: format(new Date(data.timestamp), 'HH:mm:ss')
    }))

  return (
    <div>
      <div className="header">
        <div className="container">
          <h1>Session Details</h1>
          <div className="nav">
            <Link to="/">Dashboard</Link>
            <Link to="/sessions">All Sessions</Link>
          </div>
        </div>
      </div>

      <div className="container">
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start' }}>
            <div>
              <h2>{session.title}</h2>
              <p style={{ color: '#666', marginTop: '10px' }}>
                {new Date(session.startTime).toLocaleString()}
              </p>
            </div>
            <button
              onClick={handleDelete}
              className="btn"
              style={{ background: '#dc3545', color: 'white' }}
            >
              Delete Session
            </button>
          </div>
        </div>

        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-label">Duration</div>
            <div className="stat-value">{formatDuration(session.duration)}</div>
          </div>
          <div className="stat-card">
            <div className="stat-label">Avg Heart Rate</div>
            <div className="stat-value">{session.avgHeartRate || 'N/A'}</div>
            <div className="stat-label">bpm</div>
          </div>
          <div className="stat-card">
            <div className="stat-label">Max Heart Rate</div>
            <div className="stat-value">{session.maxHeartRate || 'N/A'}</div>
            <div className="stat-label">bpm</div>
          </div>
          <div className="stat-card">
            <div className="stat-label">Min Heart Rate</div>
            <div className="stat-value">{session.minHeartRate || 'N/A'}</div>
            <div className="stat-label">bpm</div>
          </div>
          {session.calories && (
            <div className="stat-card">
              <div className="stat-label">Calories</div>
              <div className="stat-value">{Math.round(session.calories)}</div>
              <div className="stat-label">kcal</div>
            </div>
          )}
          <div className="stat-card">
            <div className="stat-label">Training Type</div>
            <div className="stat-value" style={{ fontSize: '24px' }}>{session.trainingType}</div>
          </div>
        </div>

        {session.heartRateData && session.heartRateData.length > 0 && (
          <div className="card">
            <h2>Heart Rate Chart</h2>
            <div style={{ height: '400px', marginTop: '20px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis 
                    dataKey="time" 
                    label={{ value: 'Time', position: 'insideBottom', offset: -5 }}
                  />
                  <YAxis 
                    label={{ value: 'Heart Rate (bpm)', angle: -90, position: 'insideLeft' }}
                    domain={['dataMin - 10', 'dataMax + 10']}
                  />
                  <Tooltip 
                    content={({ active, payload }) => {
                      if (active && payload && payload.length) {
                        return (
                          <div style={{ background: 'white', padding: '10px', border: '1px solid #ccc' }}>
                            <p>Time: {payload[0].payload.timestamp}</p>
                            <p>Heart Rate: {payload[0].value} bpm</p>
                          </div>
                        )
                      }
                      return null
                    }}
                  />
                  <Legend />
                  <Line 
                    type="monotone" 
                    dataKey="heartRate" 
                    stroke="#ff0000" 
                    strokeWidth={2}
                    dot={false}
                    name="Heart Rate"
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {session.notes && (
          <div className="card">
            <h2>Notes</h2>
            <p>{session.notes}</p>
          </div>
        )}

        <div className="card">
          <h2>Session Information</h2>
          <div style={{ marginTop: '20px' }}>
            <p><strong>Session ID:</strong> {session.id}</p>
            <p><strong>Person ID:</strong> {session.personId}</p>
            <p><strong>Data Points:</strong> {session.heartRateData?.length || 0}</p>
            <p><strong>Created:</strong> {new Date(session.createdAt).toLocaleString()}</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default SessionDetail
