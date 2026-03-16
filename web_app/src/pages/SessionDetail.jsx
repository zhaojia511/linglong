import React, { useState, useEffect, useMemo } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { sessionService, personService } from '../services/api'
import TrainingZonesChart from '../components/TrainingZonesChart'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { format } from 'date-fns'
import { trimHRData, detectWarmup, detectCooldown, filterNoise, calcStats } from '../lib/hrDataProcessing'
import { analyzeHRV } from '../lib/hrvAnalysis'

function SessionDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)
  const [person, setPerson] = useState(null)
  const [trimEnabled, setTrimEnabled] = useState(false)
  const [noiseFilter, setNoiseFilter] = useState(false)
  const [warmupSec, setWarmupSec] = useState(0)
  const [cooldownSec, setCooldownSec] = useState(0)

  useEffect(() => {
    loadSession()
  }, [id])

  useEffect(() => {
    if (session?.personId) {
      personService.getPerson(session.personId)
        .then(res => setPerson(res?.data ?? res))
        .catch(() => {})
    }
  }, [session?.personId])

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

  // Process HR data with trim and noise filter
  const processedData = useMemo(() => {
    if (!session?.heartRateData?.length) return []
    let data = session.heartRateData
    if (trimEnabled) {
      data = trimHRData(data, warmupSec, cooldownSec)
    }
    if (noiseFilter) {
      data = filterNoise(data)
    }
    return data
  }, [session?.heartRateData, trimEnabled, warmupSec, cooldownSec, noiseFilter])

  const processedStats = useMemo(() => {
    if (!processedData.length) return null
    return calcStats(processedData)
  }, [processedData])

  // Auto-detect warmup/cooldown on first load
  useEffect(() => {
    if (session?.heartRateData?.length > 0) {
      setWarmupSec(detectWarmup(session.heartRateData))
      setCooldownSec(detectCooldown(session.heartRateData))
    }
  }, [session?.heartRateData])

  // HRV analysis (if RR interval data exists in session)
  const hrvData = useMemo(() => {
    if (!session?.rrIntervals?.length) return null
    return analyzeHRV(session.rrIntervals)
  }, [session?.rrIntervals])

  // Prepare chart data - sample every 10th point if there's too much data
  const chartData = processedData
    .filter((_, index) => processedData.length > 100 ? index % 10 === 0 : true)
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

        {/* Data Processing Controls */}
        {session.heartRateData && session.heartRateData.length > 0 && (
          <div className="card" style={{ marginTop: '20px' }}>
            <h2>Data Processing</h2>
            <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap', marginTop: '15px', alignItems: 'center' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <input type="checkbox" checked={trimEnabled} onChange={e => setTrimEnabled(e.target.checked)} />
                Trim warmup/cooldown
              </label>
              {trimEnabled && (
                <>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    Warmup:
                    <input type="number" value={warmupSec} onChange={e => setWarmupSec(Number(e.target.value))} min={0} style={{ width: '60px' }} />s
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    Cooldown:
                    <input type="number" value={cooldownSec} onChange={e => setCooldownSec(Number(e.target.value))} min={0} style={{ width: '60px' }} />s
                  </label>
                </>
              )}
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <input type="checkbox" checked={noiseFilter} onChange={e => setNoiseFilter(e.target.checked)} />
                Noise filter
              </label>
            </div>
            {trimEnabled && processedStats && (
              <div style={{ marginTop: '10px', color: '#666', fontSize: '14px' }}>
                After processing: Avg {processedStats.avgHR} bpm | Max {processedStats.maxHR} bpm | Min {processedStats.minHR} bpm | Duration {formatDuration(processedStats.durationSeconds)}
              </div>
            )}
          </div>
        )}

        {/* HRV Analysis */}
        {hrvData && (
          <div className="card" style={{ marginTop: '20px' }}>
            <h2>HRV Analysis</h2>
            <div className="stats-grid" style={{ marginTop: '15px' }}>
              <div className="stat-card">
                <div className="stat-label">RMSSD</div>
                <div className="stat-value">{hrvData.rmssd.toFixed(1)}</div>
                <div className="stat-label">ms</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">SDNN</div>
                <div className="stat-value">{hrvData.sdnn.toFixed(1)}</div>
                <div className="stat-label">ms</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">pNN50</div>
                <div className="stat-value">{hrvData.pnn50.toFixed(1)}</div>
                <div className="stat-label">%</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Mean RR</div>
                <div className="stat-value">{hrvData.meanRR.toFixed(0)}</div>
                <div className="stat-label">ms</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Stress Level</div>
                <div className="stat-value" style={{ fontSize: '24px' }}>{hrvData.stressLevel}</div>
              </div>
            </div>
            <div style={{ marginTop: '10px', color: '#666', fontSize: '14px' }}>
              Valid intervals: {hrvData.validIntervals} / {hrvData.totalIntervals}
            </div>
          </div>
        )}

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

        <div className="card" style={{ marginTop: '20px' }}>
          <h2>Training Zones</h2>
          <TrainingZonesChart
            maxHR={person?.maxHeartRate}
            hrData={session?.heartRateData}
            avgHR={session?.avgHeartRate}
          />
        </div>

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
