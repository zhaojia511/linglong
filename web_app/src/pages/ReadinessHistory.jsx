import React, { useState, useEffect, useCallback } from 'react'
import { readinessService, personService } from '../services/api'
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer, ReferenceLine,
} from 'recharts'
import { formatDateGMT8, formatDateTimeGMT8 } from '../lib/dateTime'

const FEELING_LABELS = { 1: '😞 Very Bad', 2: '😕 Bad', 3: '😐 OK', 4: '🙂 Good', 5: '😄 Very Good' }

function readinessColor(pct) {
  if (pct == null) return '#888'
  if (pct >= 90) return '#16a34a'
  if (pct >= 75) return '#2563eb'
  if (pct >= 60) return '#d97706'
  return '#dc2626'
}

function readinessLabel(pct) {
  if (pct == null) return 'No baseline'
  if (pct >= 90) return 'High'
  if (pct >= 75) return 'Normal'
  if (pct >= 60) return 'Reduced'
  return 'Low'
}

const RANGE_OPTIONS = [
  { label: '7d', days: 7 },
  { label: '28d', days: 28 },
  { label: '60d', days: 60 },
  { label: 'All', days: null },
]

const ReadinessHistory = () => {
  const [measurements, setMeasurements] = useState([])
  const [persons, setPersons] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedPersonId, setSelectedPersonId] = useState('')
  const [selectedRange, setSelectedRange] = useState('60d')

  const loadData = useCallback(async () => {
    try {
      setLoading(true)
      setError('')
      const days = RANGE_OPTIONS.find(o => o.label === selectedRange)?.days ?? null
      const params = {}
      if (selectedPersonId) params.personId = selectedPersonId
      if (days) params.days = days
      const [mRes, pRes] = await Promise.all([
        readinessService.getMeasurements(params),
        personService.getPersons(),
      ])
      setMeasurements(mRes.data || [])
      setPersons(pRes.data || [])
    } catch (err) {
      console.error('Error loading readiness data:', err)
      setError('Failed to load readiness data')
    } finally {
      setLoading(false)
    }
  }, [selectedPersonId, selectedRange])

  useEffect(() => {
    loadData()
  }, [loadData])

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this readiness measurement?')) return
    try {
      await readinessService.deleteMeasurement(id)
      setMeasurements(prev => prev.filter(m => m.id !== id))
    } catch (err) {
      alert('Failed to delete measurement')
    }
  }

  const personMap = Object.fromEntries(persons.map(p => [p.id, p]))

  // Chart: RMSSD trend (chronological)
  const chartData = [...measurements]
    .sort((a, b) => new Date(a.measuredAt) - new Date(b.measuredAt))
    .map(m => ({
      date: formatDateGMT8(m.measuredAt),
      rmssd: m.rmssd != null ? Math.round(m.rmssd * 10) / 10 : null,
      readiness: m.readinessPct != null ? Math.round(m.readinessPct) : null,
      person: personMap[m.personId]?.name ?? 'Unknown',
    }))

  // Summary stats
  const withReadiness = measurements.filter(m => m.readinessPct != null)
  const avgReadiness = withReadiness.length
    ? Math.round(withReadiness.reduce((s, m) => s + m.readinessPct, 0) / withReadiness.length)
    : null
  const latestReadiness = withReadiness[0]?.readinessPct
  const avgRmssd = measurements.length
    ? Math.round(measurements.reduce((s, m) => s + (m.rmssd ?? 0), 0) / measurements.length * 10) / 10
    : null

  const inputStyle = { padding: '8px 10px', border: '1px solid #ddd', borderRadius: 4, fontSize: 14, background: 'white' }
  const thStyle = { textAlign: 'left', padding: '10px 14px', borderBottom: '2px solid #eee', fontSize: 12, color: '#888', textTransform: 'uppercase', letterSpacing: '0.5px' }
  const tdStyle = { padding: '10px 14px', borderBottom: '1px solid #f0f0f0', fontSize: 14 }

  if (loading) {
    return <div style={{ textAlign: 'center', padding: 60, color: '#999' }}>Loading readiness data...</div>
  }

  return (
    <div>
      <h1 style={{ margin: '0 0 20px', fontSize: 24, fontWeight: 700 }}>Readiness History</h1>

      {/* Filters */}
      <div className="card" style={{ marginBottom: 20 }}>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ minWidth: 160 }}>
            <label style={{ display: 'block', marginBottom: 4, fontSize: 13, color: '#555' }}>Athlete</label>
            <select
              value={selectedPersonId}
              onChange={e => setSelectedPersonId(e.target.value)}
              style={{ ...inputStyle, width: '100%' }}
            >
              <option value="">All Athletes</option>
              {persons.map(p => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: 4, fontSize: 13, color: '#555' }}>Range</label>
            <div style={{ display: 'flex', gap: 6 }}>
              {RANGE_OPTIONS.map(o => (
                <button
                  key={o.label}
                  onClick={() => setSelectedRange(o.label)}
                  className="btn"
                  style={{
                    padding: '8px 14px', fontSize: 13,
                    background: selectedRange === o.label ? '#2563eb' : '#f0f0f0',
                    color: selectedRange === o.label ? 'white' : '#333',
                    border: '1px solid #ddd',
                  }}
                >
                  {o.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {error && <div className="error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Summary cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 16, marginBottom: 24 }}>
        <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Measurements</div>
          <div style={{ fontSize: 32, fontWeight: 700, color: '#2563eb' }}>{measurements.length}</div>
        </div>
        <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Latest Readiness</div>
          <div style={{ fontSize: 32, fontWeight: 700, color: readinessColor(latestReadiness) }}>
            {latestReadiness != null ? `${Math.round(latestReadiness)}%` : '—'}
          </div>
          {latestReadiness != null && (
            <div style={{ fontSize: 12, color: readinessColor(latestReadiness) }}>{readinessLabel(latestReadiness)}</div>
          )}
        </div>
        <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Avg Readiness</div>
          <div style={{ fontSize: 32, fontWeight: 700, color: readinessColor(avgReadiness) }}>
            {avgReadiness != null ? `${avgReadiness}%` : '—'}
          </div>
        </div>
        <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Avg RMSSD</div>
          <div style={{ fontSize: 32, fontWeight: 700, color: '#7c3aed' }}>
            {avgRmssd != null ? `${avgRmssd}` : '—'}
          </div>
          {avgRmssd != null && <div style={{ fontSize: 12, color: '#888' }}>ms</div>}
        </div>
      </div>

      {measurements.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: 60, color: '#999' }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>💓</div>
          <div style={{ fontSize: 18 }}>No readiness measurements yet</div>
          <div style={{ fontSize: 14, marginTop: 8 }}>Measure resting HRV in the mobile app to see history here</div>
        </div>
      ) : (
        <>
          {/* Charts */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: 20, marginBottom: 20 }}>
            <div className="card" style={{ marginBottom: 0 }}>
              <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>RMSSD Trend (ms)</h3>
              <ResponsiveContainer width="100%" height={260}>
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Line
                    type="monotone"
                    dataKey="rmssd"
                    stroke="#7c3aed"
                    name="RMSSD (ms)"
                    dot={{ r: 3 }}
                    connectNulls
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>

            <div className="card" style={{ marginBottom: 0 }}>
              <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>Readiness Score (%)</h3>
              <ResponsiveContainer width="100%" height={260}>
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis domain={[0, 150]} tick={{ fontSize: 11 }} />
                  <Tooltip formatter={(v) => [`${v}%`, 'Readiness']} />
                  <ReferenceLine y={90} stroke="#16a34a" strokeDasharray="4 2" label={{ value: 'High', fill: '#16a34a', fontSize: 10 }} />
                  <ReferenceLine y={75} stroke="#2563eb" strokeDasharray="4 2" label={{ value: 'Normal', fill: '#2563eb', fontSize: 10 }} />
                  <ReferenceLine y={60} stroke="#d97706" strokeDasharray="4 2" label={{ value: 'Reduced', fill: '#d97706', fontSize: 10 }} />
                  <Line
                    type="monotone"
                    dataKey="readiness"
                    stroke="#e0192f"
                    name="Readiness %"
                    dot={{ r: 3 }}
                    connectNulls
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Measurements table */}
          <div className="card" style={{ marginBottom: 0, padding: 0, overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', borderBottom: '1px solid #f0f0f0' }}>
              <h3 style={{ margin: 0, fontSize: 16, fontWeight: 600 }}>All Measurements</h3>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ background: '#fafafa' }}>
                    <th style={thStyle}>Date</th>
                    <th style={thStyle}>Athlete</th>
                    <th style={thStyle}>Readiness</th>
                    <th style={thStyle}>RMSSD</th>
                    <th style={thStyle}>Resting HR</th>
                    <th style={thStyle}>Duration</th>
                    <th style={thStyle}>Feeling</th>
                    <th style={thStyle}></th>
                  </tr>
                </thead>
                <tbody>
                  {measurements.map(m => (
                    <tr
                      key={m.id}
                      onMouseEnter={e => e.currentTarget.style.background = '#fafafa'}
                      onMouseLeave={e => e.currentTarget.style.background = ''}
                    >
                      <td style={tdStyle}>{formatDateTimeGMT8(m.measuredAt, { seconds: true })}</td>
                      <td style={tdStyle}>{personMap[m.personId]?.name ?? 'Unknown'}</td>
                      <td style={{ ...tdStyle, fontWeight: 600, color: readinessColor(m.readinessPct) }}>
                        {m.readinessPct != null
                          ? `${Math.round(m.readinessPct)}% (${readinessLabel(m.readinessPct)})`
                          : 'No baseline'}
                      </td>
                      <td style={tdStyle}>{m.rmssd != null ? `${m.rmssd.toFixed(1)} ms` : '—'}</td>
                      <td style={tdStyle}>{m.restingHR != null ? `${m.restingHR} bpm` : '—'}</td>
                      <td style={tdStyle}>{`${Math.floor(m.durationSec / 60)}m ${m.durationSec % 60}s`}</td>
                      <td style={tdStyle}>{m.feeling != null ? FEELING_LABELS[m.feeling] : '—'}</td>
                      <td style={tdStyle}>
                        <button
                          onClick={() => handleDelete(m.id)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#dc2626', fontSize: 16 }}
                          title="Delete"
                        >
                          🗑
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  )
}

export default ReadinessHistory
