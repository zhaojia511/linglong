import React, { useState, useEffect } from 'react'
import { v4 as uuidv4 } from 'uuid'
import { sessionService, personService } from '../services/api'

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
    try {
      const data = {
        ...formData,
        duration: parseInt(formData.duration),
        distance: parseFloat(formData.distance),
        calories: parseFloat(formData.calories),
        avgHeartRate: parseInt(formData.avgHeartRate),
        maxHeartRate: parseInt(formData.maxHeartRate),
        minHeartRate: parseInt(formData.minHeartRate),
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
      <div className="flex justify-center items-center h-64">
        <div className="text-lg">Loading sessions...</div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Recording Management</h1>
        <button
          onClick={() => setShowForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          Add Session
        </button>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Session Form */}
      {showForm && (
        <div className="bg-white shadow-md rounded-lg p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">
            {editingSession ? 'Edit Session' : 'Add New Session'}
          </h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Person *</label>
              <select
                required
                value={formData.personId}
                onChange={(e) => setFormData({...formData, personId: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Select Person</option>
                {persons.map(person => (
                  <option key={person.id} value={person.id}>{person.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Session Title *</label>
              <input
                type="text"
                required
                value={formData.title}
                onChange={(e) => setFormData({...formData, title: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="e.g., Morning Run, Evening Cycling"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Training Type *</label>
              <select
                required
                value={formData.trainingType}
                onChange={(e) => setFormData({...formData, trainingType: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
              <label className="block text-sm font-medium text-gray-700 mb-1">Start Time *</label>
              <input
                type="datetime-local"
                required
                value={formData.startTime}
                onChange={(e) => setFormData({...formData, startTime: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">End Time</label>
              <input
                type="datetime-local"
                value={formData.endTime}
                onChange={(e) => setFormData({...formData, endTime: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Duration (seconds)</label>
              <input
                type="number"
                value={formData.duration}
                onChange={(e) => setFormData({...formData, duration: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="3600 for 1 hour"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Distance (meters)</label>
              <input
                type="number"
                step="0.1"
                value={formData.distance}
                onChange={(e) => setFormData({...formData, distance: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="5000 for 5km"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Calories Burned</label>
              <input
                type="number"
                step="0.1"
                value={formData.calories}
                onChange={(e) => setFormData({...formData, calories: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Avg Heart Rate (bpm)</label>
              <input
                type="number"
                value={formData.avgHeartRate}
                onChange={(e) => setFormData({...formData, avgHeartRate: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Max Heart Rate (bpm)</label>
              <input
                type="number"
                value={formData.maxHeartRate}
                onChange={(e) => setFormData({...formData, maxHeartRate: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Min Heart Rate (bpm)</label>
              <input
                type="number"
                value={formData.minHeartRate}
                onChange={(e) => setFormData({...formData, minHeartRate: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
              <textarea
                value={formData.notes}
                onChange={(e) => setFormData({...formData, notes: e.target.value})}
                rows={3}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Additional notes about the session..."
              />
            </div>

            <div className="md:col-span-2 flex gap-4">
              <button
                type="submit"
                className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
              >
                {editingSession ? 'Update Session' : 'Add Session'}
              </button>
              <button
                type="button"
                onClick={handleCancel}
                className="bg-gray-500 text-white px-4 py-2 rounded-lg hover:bg-gray-600"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Sessions List */}
      <div className="bg-white shadow-md rounded-lg overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-xl font-semibold">Training Sessions ({sessions.length})</h2>
        </div>

        {sessions.length === 0 ? (
          <div className="p-6 text-center text-gray-500">
            No sessions found. Add your first training session to get started.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Title
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Type
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date & Time
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Duration
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Distance
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Avg HR
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {sessions.map((session) => (
                  <tr key={session.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {session.title || 'Untitled Session'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 capitalize">
                      {session.trainingType || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDate(session.startTime)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDuration(session.duration)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {session.distance ? `${(session.distance / 1000).toFixed(2)} km` : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {session.avgHeartRate ? `${session.avgHeartRate} bpm` : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button
                        onClick={() => handleEdit(session)}
                        className="text-blue-600 hover:text-blue-900 mr-4"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(session.id)}
                        className="text-red-600 hover:text-red-900"
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
