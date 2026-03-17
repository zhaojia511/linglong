import React, { useState, useEffect } from 'react'
import { v4 as uuidv4 } from 'uuid'
import { personService } from '../services/api'

const inputStyle = { width: '100%', padding: '8px 10px', border: '1px solid #ddd', borderRadius: 4, fontSize: 14, boxSizing: 'border-box' }
const labelStyle = { display: 'block', marginBottom: 4, fontWeight: 500, fontSize: 14 }
const thStyle = { textAlign: 'left', padding: '10px 12px', borderBottom: '2px solid #eee', fontSize: 13, color: '#666' }
const tdStyle = { padding: '10px 12px', borderBottom: '1px solid #eee', fontSize: 14 }

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
      const response = await personService.getPersons({ role: 'athlete' })
      setPersons(response.data || [])
    } catch (error) {
      console.error('Error loading persons:', error)
      setError('Failed to load persons')
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!formData.name.trim()) { setError('Name is required'); return }
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
        await personService.upsertPerson({ ...data, id: editingPerson.id })
      } else {
        await personService.upsertPerson({ ...data, id: uuidv4() })
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
      await personService.deletePerson(personId)
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
      <div style={{ textAlign: 'center', padding: 40 }}>Loading...</div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h1 style={{ margin: 0 }}>Athlete Management</h1>
        <button className="btn btn-primary" onClick={() => setShowForm(true)}>Add Athlete</button>
      </div>

      {error && (
        <div className="error">{error}</div>
      )}

      {/* Person Form */}
      {showForm && (
        <div className="card" style={{ marginBottom: 24 }}>
          <h2 style={{ marginTop: 0, marginBottom: 16 }}>
            {editingPerson ? 'Edit Person' : 'Add New Person'}
          </h2>
          <form onSubmit={handleSubmit}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
              <div>
                <label style={labelStyle}>Name *</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({...formData, name: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Age</label>
                <input
                  type="number"
                  value={formData.age}
                  onChange={(e) => setFormData({...formData, age: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Gender</label>
                <select
                  value={formData.gender}
                  onChange={(e) => setFormData({...formData, gender: e.target.value})}
                  style={inputStyle}
                >
                  <option value="">Select Gender</option>
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                  <option value="other">Other</option>
                </select>
              </div>

              <div>
                <label style={labelStyle}>Height (cm)</label>
                <input
                  type="number"
                  step="0.1"
                  value={formData.height}
                  onChange={(e) => setFormData({...formData, height: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Weight (kg)</label>
                <input
                  type="number"
                  step="0.1"
                  value={formData.weight}
                  onChange={(e) => setFormData({...formData, weight: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Role</label>
                <select
                  value={formData.role}
                  onChange={(e) => setFormData({...formData, role: e.target.value})}
                  style={inputStyle}
                >
                  <option value="athlete">Athlete</option>
                  <option value="coach">Coach</option>
                </select>
              </div>

              <div>
                <label style={labelStyle}>Max Heart Rate (bpm)</label>
                <input
                  type="number"
                  value={formData.maxHeartRate}
                  onChange={(e) => setFormData({...formData, maxHeartRate: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Resting Heart Rate (bpm)</label>
                <input
                  type="number"
                  value={formData.restingHeartRate}
                  onChange={(e) => setFormData({...formData, restingHeartRate: e.target.value})}
                  style={inputStyle}
                />
              </div>

              <div>
                <label style={labelStyle}>Fitness Level</label>
                <select
                  value={formData.fitness_level}
                  onChange={(e) => setFormData({...formData, fitness_level: e.target.value})}
                  style={inputStyle}
                >
                  <option value="">Select Level</option>
                  <option value="beginner">Beginner</option>
                  <option value="intermediate">Intermediate</option>
                  <option value="advanced">Advanced</option>
                  <option value="elite">Elite</option>
                </select>
              </div>

              <div style={{ gridColumn: 'span 2', display: 'flex', gap: 12, marginTop: 4 }}>
                <button type="submit" className="btn btn-primary">
                  {editingPerson ? 'Update Person' : 'Add Person'}
                </button>
                <button type="button" className="btn" style={{ background: '#6c757d', color: 'white' }} onClick={handleCancel}>
                  Cancel
                </button>
              </div>
            </div>
          </form>
        </div>
      )}

      {/* Persons List */}
      <div className="card" style={{ padding: 0 }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid #eee' }}>
          <h2 style={{ margin: 0 }}>Athletes ({persons.length})</h2>
        </div>

        {persons.length === 0 ? (
          <p style={{ textAlign: 'center', color: '#999', padding: 40 }}>No athletes found. Add your first athlete to get started.</p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={thStyle}>Name</th>
                  <th style={thStyle}>Age</th>
                  <th style={thStyle}>Role</th>
                  <th style={thStyle}>Max HR</th>
                  <th style={thStyle}>Rest HR</th>
                  <th style={thStyle}>Sport</th>
                  <th style={thStyle}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {persons.map((person) => (
                  <tr key={person.id}>
                    <td style={tdStyle}>{person.name}</td>
                    <td style={tdStyle}>{person.age || '-'}</td>
                    <td style={{ ...tdStyle, textTransform: 'capitalize' }}>{person.role || 'athlete'}</td>
                    <td style={tdStyle}>{person.maxHeartRate ? `${person.maxHeartRate} bpm` : '-'}</td>
                    <td style={tdStyle}>{person.restingHeartRate ? `${person.restingHeartRate} bpm` : '-'}</td>
                    <td style={tdStyle}>{person.sport_type || '-'}</td>
                    <td style={tdStyle}>
                      <button
                        className="btn"
                        style={{ marginRight: 8, padding: '4px 10px', fontSize: 13 }}
                        onClick={() => handleEdit(person)}
                      >
                        Edit
                      </button>
                      <button
                        className="btn"
                        style={{ background: '#dc3545', color: 'white', padding: '4px 10px', fontSize: 13 }}
                        onClick={() => handleDelete(person.id)}
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
