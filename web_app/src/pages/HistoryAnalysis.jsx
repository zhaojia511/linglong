import React, { useState, useEffect } from 'react'
import { supabase } from '../services/supabaseClient'
import api from '../services/api'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts'
import { getZoneForHR, ZONE_DEFINITIONS } from '../lib/trainingZones'

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
  // Track if default date has been set
  const [defaultDateSet, setDefaultDateSet] = useState(false)

  useEffect(() => {
    loadData()
  }, [filters])

  // Set default date range to nearest week or month on first load
  useEffect(() => {
    if (!defaultDateSet && sessions.length > 0 && !filters.startDate && !filters.endDate) {
      // Find the most recent session date
      const mostRecent = sessions.reduce((latest, s) => {
        const d = new Date(s.start_time)
        return d > latest ? d : latest
      }, new Date(sessions[0].start_time))

      // Default: show the nearest week (last 7 days) or month (last 30 days)
      // You can switch between week/month by changing daysBack
      const daysBack = 7 // set to 30 for month
      const start = new Date(mostRecent)
      start.setDate(start.getDate() - (daysBack - 1))
      const startDateStr = start.toISOString().slice(0, 10)
      const endDateStr = mostRecent.toISOString().slice(0, 10)
      setFilters(f => ({ ...f, startDate: startDateStr, endDate: endDateStr }))
      setDefaultDateSet(true)
    }
  }, [sessions, filters.startDate, filters.endDate, defaultDateSet])

  const loadData = async () => {
    try {
      setLoading(true)

      // Load stats with filters
      const statsParams = new URLSearchParams()
      if (filters.personId) statsParams.append('personId', filters.personId)
      if (filters.startDate) statsParams.append('startDate', filters.startDate)
      if (filters.endDate) statsParams.append('endDate', filters.endDate)

      const [statsResponse, sessionsResponse, personsResponse] = await Promise.all([
        api.get(`/sessions/stats/summary?${statsParams}`),
        api.get('/sessions?limit=100'),
        api.get('/persons')
      ])

      setStats(statsResponse.data.data)
      setSessions(sessionsResponse.data.data || [])
      setPersons(personsResponse.data.data || [])
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
    setFilters({
      personId: '',
      startDate: '',
      endDate: ''
    })
  }

  // Prepare chart data
  const prepareHeartRateData = () => {
    const filteredSessions = sessions
      .filter(s => s.avgHeartRate)
      .sort((a, b) => new Date(a.startTime) - new Date(b.startTime))
      .slice(-20) // Last 20 sessions

    return filteredSessions.map(session => ({
      date: new Date(session.startTime).toLocaleDateString(),
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
      const date = new Date(session.startTime)
      const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`

      if (!monthlyStats[monthKey]) {
        monthlyStats[monthKey] = {
          month: date.toLocaleDateString('en-US', { year: 'numeric', month: 'short' }),
          sessions: 0,
          totalDuration: 0,
          totalCalories: 0
        }
      }

      monthlyStats[monthKey].sessions += 1
      monthlyStats[monthKey].totalDuration += session.duration || 0
      monthlyStats[monthKey].totalCalories += session.calories || 0
    })

    return Object.values(monthlyStats).sort((a, b) => a.month.localeCompare(b.month))
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

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-lg">Loading analysis data...</div>
      </div>
    )
  }

  return (
    <div className="container">
      <div className="mb-6">
        <h1 className="page-title">Analysis</h1>

        {/* Filters */}
        <div className="bg-white shadow-md rounded-lg p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">Filters</h2>
          <div className="flex flex-col md:flex-row md:items-end gap-4">
            <div className="flex-1 min-w-[160px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">Person</label>
              <select
                value={filters.personId}
                onChange={(e) => handleFilterChange('personId', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">All Persons</option>
                {persons.map(person => (
                  <option key={person.id} value={person.id}>{person.name}</option>
                ))}
              </select>
            </div>
            <div className="flex-1 min-w-[160px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
              <input
                type="date"
                value={filters.startDate}
                onChange={(e) => handleFilterChange('startDate', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div className="flex-1 min-w-[160px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">End Date</label>
              <input
                type="date"
                value={filters.endDate}
                onChange={(e) => handleFilterChange('endDate', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div className="flex items-end">
              <button
                onClick={clearFilters}
                className="bg-gray-500 text-white px-4 py-2 rounded-lg hover:bg-gray-600 w-full md:w-auto"
              >
                Clear Filters
              </button>
            </div>
          </div>
        </div>

        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}

        {/* Summary Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div className="bg-white shadow-md rounded-lg p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Total Sessions</h3>
              <p className="text-3xl font-bold text-blue-600">{stats.totalSessions}</p>
            </div>

            <div className="bg-white shadow-md rounded-lg p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Total Duration</h3>
              <p className="text-3xl font-bold text-green-600">
                {Math.floor(stats.totalDuration / 3600)}h {Math.floor((stats.totalDuration % 3600) / 60)}m
              </p>
            </div>

            <div className="bg-white shadow-md rounded-lg p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Total Calories</h3>
              <p className="text-3xl font-bold text-orange-600">{Math.round(stats.totalCalories)} kcal</p>
            </div>

            <div className="bg-white shadow-md rounded-lg p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Avg Heart Rate</h3>
              <p className="text-3xl font-bold text-red-600">
                {stats.avgHeartRate ? `${stats.avgHeartRate} bpm` : 'N/A'}
              </p>
            </div>
          </div>
        )}

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          {/* Heart Rate Trend */}
          <div className="bg-white shadow-md rounded-lg p-6">
            <h3 className="text-xl font-semibold mb-4">Heart Rate Trend (Last 20 Sessions)</h3>
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

          {/* Training Types Distribution */}
          <div className="bg-white shadow-md rounded-lg p-6">
            <h3 className="text-xl font-semibold mb-4">Training Types Distribution</h3>
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
        <div className="bg-white shadow-md rounded-lg p-6 mb-8">
          <h3 className="text-xl font-semibold mb-4">Monthly Progress</h3>
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
            <div className="bg-white shadow-md rounded-lg p-6 mb-8">
              <h3 className="text-xl font-semibold mb-4">Zone Distribution (All Sessions)</h3>
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
        <div className="bg-white shadow-md rounded-lg overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-xl font-semibold">Recent Sessions</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Person
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Type
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Duration
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Avg HR
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Calories
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {sessions.slice(0, 10).map((session) => (
                  <tr key={session.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {new Date(session.startTime).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {persons.find(p => p.id === session.personId)?.name || 'Unknown'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 capitalize">
                      {session.trainingType || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {session.duration ? `${Math.floor(session.duration / 60)}m ${session.duration % 60}s` : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {session.avgHeartRate ? `${session.avgHeartRate} bpm` : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {session.calories ? `${Math.round(session.calories)} kcal` : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}

export default HistoryAnalysis