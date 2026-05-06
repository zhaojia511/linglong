import React, { useState, useEffect } from 'react'
import { sessionService, personService } from '../services/api'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts'
import { getZoneForHR, ZONE_DEFINITIONS } from '../lib/trainingZones'
import { formatDateGMT8, formatMonthKeyGMT8, formatMonthLabelGMT8 } from '../lib/dateTime'

const HistoryAnalysis = () => {
  const [stats, setStats] = useState(null)
  const [sessions, setSessions] = useState([])
  const [persons, setPersons] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [filters, setFilters] = useState({
    personId: '',
    startDate: '',
    endDate: ''
  })

  useEffect(() => {
    loadData()
  }, [filters])

  const loadData = async () => {
    try {
      setLoading(true)

      const params = {}
      if (filters.personId) params.personId = filters.personId
      if (filters.startDate) params.startDate = filters.startDate
      if (filters.endDate) params.endDate = filters.endDate

      const [statsResponse, sessionsResponse, personsResponse] = await Promise.all([
        sessionService.getStats(params),
        sessionService.getSessions({ limit: 100 }),
        personService.getPersons()
      ])

      setStats(statsResponse.data)
      setSessions(sessionsResponse.data || [])
      setPersons(personsResponse.data || [])
    } catch (error) {
      console.error('Error loading analysis data:', error)
      setError('Failed to load analysis data')
    } finally {
      setLoading(false)
    }
  }

  const handleFilterChange = (field, value) => {
    setFilters(prev => ({
      ...prev,
      [field]: value
    }))
  }

  const clearFilters = () => {
    setFilters({ personId: '', startDate: '', endDate: '' })
  }

  const applyPreset = (days) => {
    const end = new Date()
    const start = new Date()
    start.setDate(start.getDate() - days)
    setFilters({
      ...filters,
      startDate: start.toISOString().split('T')[0],
      endDate: end.toISOString().split('T')[0]
    })
  }

  const prepareHeartRateData = () => {
    return sessions
      .filter(s => s.avgHeartRate)
      .sort((a, b) => new Date(a.startTime) - new Date(b.startTime))
      .slice(-20)
      .map(session => ({
        date: formatDateGMT8(session.startTime),
        avgHR: session.avgHeartRate,
        maxHR: session.maxHeartRate,
        person: persons.find(p => p.id === session.personId)?.name || 'Unknown'
      }))
  }

  const prepareTrainingTypeData = () => {
    if (!stats?.trainingTypes) return []
    return Object.entries(stats.trainingTypes).map(([type, count]) => ({
      type: type.charAt(0).toUpperCase() + type.slice(1),
      count,
      percentage: ((count / stats.totalSessions) * 100).toFixed(1)
    }))
  }

  const prepareMonthlyData = () => {
    const monthlyStats = {}
    sessions.forEach(session => {
      const monthKey = formatMonthKeyGMT8(session.startTime)
      if (!monthlyStats[monthKey]) {
        monthlyStats[monthKey] = {
          month: formatMonthLabelGMT8(session.startTime),
          monthKey,
          sessions: 0,
          totalDuration: 0,
          totalCalories: 0
        }
      }
      monthlyStats[monthKey].sessions += 1
      monthlyStats[monthKey].totalDuration += session.duration || 0
      monthlyStats[monthKey].totalCalories += session.calories || 0
    })
    return Object.values(monthlyStats).sort((a, b) => a.monthKey.localeCompare(b.monthKey))
  }

  const prepareZoneSummary = () => {
    const counts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
    let total = 0
    sessions.forEach(s => {
      const person = persons.find(p => p.id === s.personId)
      if (!person?.maxHeartRate || !s.avgHeartRate) return
      const zone = getZoneForHR(s.avgHeartRate, person.maxHeartRate)
      if (zone) { counts[zone.zone]++; total++ }
    })
    if (total === 0) return null
    return { counts, total }
  }

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8']

  const inputStyle = { width: '100%', padding: '8px 10px', border: '1px solid #ddd', borderRadius: 4, fontSize: 14 }
  const thStyle = { textAlign: 'left', padding: '10px 14px', borderBottom: '2px solid #eee', fontSize: 12, color: '#888', textTransform: 'uppercase', letterSpacing: '0.5px' }
  const tdStyle = { padding: '10px 14px', borderBottom: '1px solid #f0f0f0', fontSize: 14 }

  if (loading) {
    return <div style={{ textAlign: 'center', padding: 60, color: '#999' }}>Loading analysis data...</div>
  }

  return (
    <div>
      <h1 style={{ margin: '0 0 20px', fontSize: 24, fontWeight: 700 }}>Training History Analysis</h1>

      {/* Filters */}
      <div className="card" style={{ marginBottom: 20 }}>
        <h2 style={{ margin: '0 0 14px', fontSize: 16, fontWeight: 600 }}>Filters</h2>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ minWidth: 160 }}>
            <label style={{ display: 'block', marginBottom: 4, fontSize: 13, color: '#555' }}>Person</label>
            <select value={filters.personId} onChange={(e) => handleFilterChange('personId', e.target.value)} style={inputStyle}>
              <option value="">All Persons</option>
              {persons.map(person => (
                <option key={person.id} value={person.id}>{person.name}</option>
              ))}
            </select>
          </div>
          <div style={{ minWidth: 140 }}>
            <label style={{ display: 'block', marginBottom: 4, fontSize: 13, color: '#555' }}>Start Date</label>
            <input type="date" value={filters.startDate} onChange={(e) => handleFilterChange('startDate', e.target.value)} style={inputStyle} />
          </div>
          <div style={{ minWidth: 140 }}>
            <label style={{ display: 'block', marginBottom: 4, fontSize: 13, color: '#555' }}>End Date</label>
            <input type="date" value={filters.endDate} onChange={(e) => handleFilterChange('endDate', e.target.value)} style={inputStyle} />
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {[7, 30, 90].map(days => (
              <button key={days} onClick={() => applyPreset(days)} className="btn" style={{ padding: '8px 12px', fontSize: 13, background: '#f0f0f0', border: '1px solid #ddd' }}>
                Last {days}d
              </button>
            ))}
            <button onClick={clearFilters} className="btn" style={{ padding: '8px 12px', fontSize: 13, background: '#666', color: 'white', border: 'none' }}>
              Clear
            </button>
          </div>
        </div>
      </div>

      {error && (
        <div className="error" style={{ marginBottom: 16 }}>{error}</div>
      )}

      {/* Summary Stats */}
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16, marginBottom: 24 }}>
          <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
            <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Total Sessions</div>
            <div style={{ fontSize: 32, fontWeight: 700, color: '#2563eb' }}>{stats.totalSessions}</div>
          </div>
          <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
            <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Total Duration</div>
            <div style={{ fontSize: 32, fontWeight: 700, color: '#16a34a' }}>
              {Math.floor(stats.totalDuration / 3600)}h {Math.floor((stats.totalDuration % 3600) / 60)}m
            </div>
          </div>
          <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
            <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Total Calories</div>
            <div style={{ fontSize: 32, fontWeight: 700, color: '#ea580c' }}>{Math.round(stats.totalCalories)} kcal</div>
          </div>
          <div className="card" style={{ marginBottom: 0, textAlign: 'center' }}>
            <div style={{ fontSize: 13, color: '#888', marginBottom: 6 }}>Avg Heart Rate</div>
            <div style={{ fontSize: 32, fontWeight: 700, color: '#e0192f' }}>
              {stats.avgHeartRate ? `${stats.avgHeartRate} bpm` : 'N/A'}
            </div>
          </div>
        </div>
      )}

      {/* Charts */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: 20, marginBottom: 20 }}>
        <div className="card" style={{ marginBottom: 0 }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>Heart Rate Trend (Last 20 Sessions)</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={prepareHeartRateData()}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="avgHR" stroke="#8884d8" name="Avg HR (bpm)" />
              <Line type="monotone" dataKey="maxHR" stroke="#82ca9d" name="Max HR (bpm)" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="card" style={{ marginBottom: 0 }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>Training Types Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={prepareTrainingTypeData()}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ type, percentage }) => `${type}: ${percentage}%`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="count"
              >
                {prepareTrainingTypeData().map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Monthly Progress */}
      <div className="card" style={{ marginBottom: 20 }}>
        <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>Monthly Progress</h3>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={prepareMonthlyData()}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="month" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Bar dataKey="sessions" fill="#8884d8" name="Sessions" />
            <Bar dataKey="totalCalories" fill="#82ca9d" name="Calories" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Zone Distribution Summary */}
      {(() => {
        const zoneSummary = prepareZoneSummary()
        if (!zoneSummary) return null
        return (
          <div className="card" style={{ marginBottom: 20 }}>
            <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>Zone Distribution (All Sessions)</h3>
            <div style={{ display: 'flex', gap: 4, height: 32, borderRadius: 4, overflow: 'hidden' }}>
              {ZONE_DEFINITIONS.map(z => {
                const pct = Math.round((zoneSummary.counts[z.zone] / zoneSummary.total) * 100)
                if (pct === 0) return null
                return (
                  <div
                    key={z.zone}
                    title={`Zone ${z.zone}: ${z.name} — ${pct}%`}
                    style={{ background: z.color, flex: pct, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 11, fontWeight: 'bold' }}
                  >
                    {pct >= 8 ? `Z${z.zone} ${pct}%` : ''}
                  </div>
                )
              })}
            </div>
            <div style={{ display: 'flex', gap: 16, marginTop: 8, flexWrap: 'wrap' }}>
              {ZONE_DEFINITIONS.map(z => (
                <span key={z.zone} style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 4 }}>
                  <span style={{ width: 10, height: 10, background: z.color, display: 'inline-block', borderRadius: 2 }} />
                  Z{z.zone} {z.name}: {Math.round((zoneSummary.counts[z.zone] / zoneSummary.total) * 100)}%
                </span>
              ))}
            </div>
          </div>
        )
      })()}

      {/* Recent Sessions Table */}
      <div className="card" style={{ marginBottom: 0, padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid #f0f0f0' }}>
          <h3 style={{ margin: 0, fontSize: 16, fontWeight: 600 }}>Recent Sessions</h3>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#fafafa' }}>
                <th style={thStyle}>Date</th>
                <th style={thStyle}>Person</th>
                <th style={thStyle}>Type</th>
                <th style={thStyle}>Duration</th>
                <th style={thStyle}>Avg HR</th>
                <th style={thStyle}>Calories</th>
              </tr>
            </thead>
            <tbody>
              {sessions.slice(0, 10).map((session) => (
                <tr key={session.id} style={{ cursor: 'default' }}
                  onMouseEnter={e => e.currentTarget.style.background = '#fafafa'}
                  onMouseLeave={e => e.currentTarget.style.background = ''}
                >
                  <td style={tdStyle}>{formatDateGMT8(session.startTime)}</td>
                  <td style={tdStyle}>{persons.find(p => p.id === session.personId)?.name || 'Unknown'}</td>
                  <td style={{ ...tdStyle, textTransform: 'capitalize' }}>{session.trainingType || '-'}</td>
                  <td style={tdStyle}>{session.duration ? `${Math.floor(session.duration / 60)}m ${session.duration % 60}s` : '-'}</td>
                  <td style={tdStyle}>{session.avgHeartRate ? `${session.avgHeartRate} bpm` : '-'}</td>
                  <td style={tdStyle}>{session.calories ? `${Math.round(session.calories)} kcal` : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default HistoryAnalysis
