import { supabase } from './supabaseClient'

// snake_case → camelCase for session objects returned from Supabase
function toSession(row) {
  if (!row) return null
  return {
    id: row.id,
    personId: row.person_id,
    title: row.title,
    trainingType: row.training_type,
    startTime: row.start_time,
    endTime: row.end_time,
    duration: row.duration,
    distance: row.distance,
    avgHeartRate: row.avg_heart_rate,
    maxHeartRate: row.max_heart_rate,
    minHeartRate: row.min_heart_rate,
    calories: row.calories,
    heartRateData: row.heart_rate_data ?? [],
    rrIntervals: row.rr_intervals ?? [],
    notes: row.notes,
    createdAt: row.created_at,
  }
}

// camelCase → snake_case for session objects sent to Supabase
function fromSession(session) {
  const row = {}
  if (session.id !== undefined) row.id = session.id
  if (session.personId !== undefined) row.person_id = session.personId
  if (session.title !== undefined) row.title = session.title
  if (session.trainingType !== undefined) row.training_type = session.trainingType
  if (session.startTime !== undefined) row.start_time = session.startTime
  if (session.endTime !== undefined) row.end_time = session.endTime
  if (session.duration !== undefined) row.duration = session.duration
  if (session.distance !== undefined) row.distance = session.distance
  if (session.avgHeartRate !== undefined) row.avg_heart_rate = session.avgHeartRate
  if (session.maxHeartRate !== undefined) row.max_heart_rate = session.maxHeartRate
  if (session.minHeartRate !== undefined) row.min_heart_rate = session.minHeartRate
  if (session.calories !== undefined) row.calories = session.calories
  if (session.heartRateData !== undefined) row.heart_rate_data = session.heartRateData
  if (session.rrIntervals !== undefined) row.rr_intervals = session.rrIntervals
  if (session.notes !== undefined) row.notes = session.notes
  return row
}

// snake_case → camelCase for person objects
function toPerson(row) {
  if (!row) return null
  return {
    id: row.id,
    name: row.name,
    age: row.age,
    gender: row.gender,
    weight: row.weight,
    height: row.height,
    maxHeartRate: row.max_heart_rate,
    restingHeartRate: row.resting_heart_rate,
    role: row.role,
    sport_type: row.sport_type,
    fitness_level: row.fitness_level,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

// camelCase → snake_case for person objects
function fromPerson(person) {
  const row = {}
  if (person.id !== undefined) row.id = person.id
  if (person.name !== undefined) row.name = person.name
  if (person.age !== undefined) row.age = person.age
  if (person.gender !== undefined) row.gender = person.gender
  if (person.weight !== undefined) row.weight = person.weight
  if (person.height !== undefined) row.height = person.height
  if (person.maxHeartRate !== undefined) row.max_heart_rate = person.maxHeartRate
  if (person.restingHeartRate !== undefined) row.resting_heart_rate = person.restingHeartRate
  if (person.role !== undefined) row.role = person.role
  if (person.sport_type !== undefined) row.sport_type = person.sport_type
  if (person.fitness_level !== undefined) row.fitness_level = person.fitness_level
  return row
}

// --- sessionService (matches existing export name in api.js) ---

export const sessionService = {
  async getSessions({ limit = 50, offset = 0, personId, startDate, endDate } = {}) {
    let query = supabase
      .from('training_sessions')
      .select('*')
      .order('start_time', { ascending: false })
      .range(offset, offset + limit - 1)
    if (personId) query = query.eq('person_id', personId)
    if (startDate) query = query.gte('start_time', startDate)
    if (endDate) query = query.lte('start_time', endDate)
    const { data, error } = await query
    if (error) throw error
    return { data: (data ?? []).map(toSession) }
  },

  async getSession(id) {
    const { data, error } = await supabase
      .from('training_sessions')
      .select('*')
      .eq('id', id)
      .single()
    if (error) throw error
    return { data: toSession(data) }
  },

  async getStats({ startDate, endDate, personId } = {}) {
    const { data, error } = await supabase.rpc('get_training_stats', {
      p_start_date: startDate || null,
      p_end_date: endDate || null,
      p_person_id: personId || null,
    })
    if (error) throw error
    return { data: Array.isArray(data) ? data[0] ?? null : data }
  },

  async deleteSession(id) {
    const { error } = await supabase
      .from('training_sessions')
      .delete()
      .eq('id', id)
    if (error) throw error
    return { data: { success: true } }
  },

  async upsertSession(session) {
    const { data: { user } } = await supabase.auth.getUser()
    const row = { ...fromSession(session), user_id: user.id }
    const { data, error } = await supabase
      .from('training_sessions')
      .upsert(row, { onConflict: 'id' })
      .select()
      .single()
    if (error) throw error
    return { data: toSession(data) }
  },
}

// --- personService (matches existing export name in api.js) ---

export const personService = {
  async getPersons({ role } = {}) {
    let query = supabase
      .from('persons')
      .select('*')
      .order('created_at', { ascending: false })
    if (role) query = query.eq('role', role)
    const { data, error } = await query
    if (error) throw error
    return { data: (data ?? []).map(toPerson) }
  },

  async getPerson(id) {
    const { data, error } = await supabase
      .from('persons')
      .select('*')
      .eq('id', id)
      .single()
    if (error) throw error
    return { data: toPerson(data) }
  },

  async upsertPerson(person) {
    const { data: { user } } = await supabase.auth.getUser()
    const row = { ...fromPerson(person), user_id: user.id }
    const { data, error } = await supabase
      .from('persons')
      .upsert(row, { onConflict: 'id' })
      .select()
      .single()
    if (error) throw error
    return { data: toPerson(data) }
  },

  async deletePerson(id) {
    const { error } = await supabase
      .from('persons')
      .delete()
      .eq('id', id)
    if (error) throw error
    return { data: { success: true } }
  },
}
