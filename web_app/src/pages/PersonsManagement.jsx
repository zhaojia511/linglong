import React, { useState, useEffect } from 'react'
import { supabase } from '../services/supabaseClient'
import api from '../services/api'

const PersonsManagement = () => {
  const [persons, setPersons] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editingPerson, setEditingPerson] = useState(null)
  const [formData, setFormData] = useState({
    name: '',
    age: '',
    gender: '',
    height: '',
    weight: '',
    maxHeartRate: '',
    restingHeartRate: '',
    role: 'athlete',
    sport_type: '',
    fitness_level: ''
  })

  useEffect(() => {
    loadPersons()
  }, [])

  const loadPersons = async () => {
    try {
      setLoading(true)
      // Request only persons with role 'athlete'
      const response = await api.get('/persons', { params: { role: 'athlete' } })
      setPersons(response.data.data || [])
    } catch (error) {
      console.error('Error loading persons:', error)
      setError('Failed to load persons')
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {

      // Build payload and only include numeric fields when provided
      const data = { ...formData }
      if (formData.age === '' || formData.age == null) {
        delete data.age
      } else {
        data.age = parseInt(formData.age)
      }
      if (formData.height === '' || formData.height == null) {
        delete data.height
      } else {
        data.height = parseFloat(formData.height)
      }
      if (formData.weight === '' || formData.weight == null) {
        delete data.weight
      } else {
        data.weight = parseFloat(formData.weight)
      }

      if (editingPerson) {
        await api.post(`/persons`, { ...data, id: editingPerson.id })
      } else {
        await api.post('/persons', data)
      }

      await loadPersons()
      setShowForm(false)
      setEditingPerson(null)
      resetForm()
    } catch (error) {
      console.error('Error saving person:', error)
      setError('Failed to save person')
    }
  }

  const handleEdit = (person) => {
    setEditingPerson(person)
    setFormData({
      name: person.name || '',
      age: person.age?.toString() || '',
      gender: person.gender || '',
      height: person.height?.toString() || '',
      weight: person.weight?.toString() || '',
      maxHeartRate: person.maxHeartRate?.toString() || '',
      restingHeartRate: person.restingHeartRate?.toString() || '',
      role: person.role || 'athlete',
      sport_type: person.sport_type || '',
      fitness_level: person.fitness_level || ''
    })
    setShowForm(true)
  }

  const handleDelete = async (personId) => {
    if (!window.confirm('Are you sure you want to delete this person?')) return

    try {
      // Note: Backend doesn't have delete endpoint, so we'll just remove from UI
      setPersons(persons.filter(p => p.id !== personId))
    } catch (error) {
      console.error('Error deleting person:', error)
      setError('Failed to delete person')
    }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      age: '',
      gender: '',
      height: '',
      weight: '',
      maxHeartRate: '',
      restingHeartRate: '',
      role: 'athlete',
      sport_type: '',
      fitness_level: ''
    })
  }

  const handleCancel = () => {
    setShowForm(false)
    setEditingPerson(null)
    resetForm()
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-lg">Loading persons...</div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Athlete Management</h1>
        <button
          onClick={() => setShowForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          Add Athlete
        </button>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Person Form */}
      {showForm && (
        <div className="bg-white shadow-md rounded-lg p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">
            {editingPerson ? 'Edit Person' : 'Add New Person'}
          </h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Name *</label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData({...formData, name: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Age</label>
              <input
                type="number"
                value={formData.age}
                onChange={(e) => setFormData({...formData, age: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Gender</label>
              <select
                value={formData.gender}
                onChange={(e) => setFormData({...formData, gender: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Select Gender</option>
                <option value="male">Male</option>
                <option value="female">Female</option>
                <option value="other">Other</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Height (cm)</label>
              <input
                type="number"
                step="0.1"
                value={formData.height}
                onChange={(e) => setFormData({...formData, height: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Weight (kg)</label>
              <input
                type="number"
                step="0.1"
                value={formData.weight}
                onChange={(e) => setFormData({...formData, weight: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
              <select
                value={formData.role}
                onChange={(e) => setFormData({...formData, role: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="athlete">Athlete</option>
                <option value="coach">Coach</option>
              </select>
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
              <label className="block text-sm font-medium text-gray-700 mb-1">Resting Heart Rate (bpm)</label>
              <input
                type="number"
                value={formData.restingHeartRate}
                onChange={(e) => setFormData({...formData, restingHeartRate: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Fitness Level</label>
              <select
                value={formData.fitness_level}
                onChange={(e) => setFormData({...formData, fitness_level: e.target.value})}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Select Level</option>
                <option value="beginner">Beginner</option>
                <option value="intermediate">Intermediate</option>
                <option value="advanced">Advanced</option>
                <option value="elite">Elite</option>
              </select>
            </div>

            <div className="md:col-span-2 flex gap-4">
              <button
                type="submit"
                className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
              >
                {editingPerson ? 'Update Person' : 'Add Person'}
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

      {/* Persons List */}
      <div className="bg-white shadow-md rounded-lg overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-xl font-semibold">Persons ({persons.length})</h2>
                  <h2 className="text-xl font-semibold">Athletes ({persons.length})</h2>
        </div>

        {persons.length === 0 ? (
          <div className="p-6 text-center text-gray-500">
            No athletes found. Add your first athlete to get started.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Age
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Role
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Max HR
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Rest HR
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Sport
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {persons.map((person) => (
                  <tr key={person.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {person.name}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {person.age || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 capitalize">
                      {person.role || 'athlete'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {person.maxHeartRate ? `${person.maxHeartRate} bpm` : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {person.restingHeartRate ? `${person.restingHeartRate} bpm` : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {person.sport_type || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button
                        onClick={() => handleEdit(person)}
                        className="text-blue-600 hover:text-blue-900 mr-4"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(person.id)}
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

export default PersonsManagement