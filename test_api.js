const axios = require('axios')

const BASE_URL = 'http://localhost:3000/api'

// Test health endpoint
async function testHealth() {
  try {
    const response = await axios.get(`${BASE_URL}/health`)
    console.log('✅ Health endpoint:', response.data)
    return true
  } catch (error) {
    console.log('❌ Health endpoint failed:', error.message)
    return false
  }
}

// Test auth endpoint (will fail without token, but should respond)
async function testAuth() {
  try {
    const response = await axios.post(`${BASE_URL}/auth/login`, {
      email: 'test@example.com',
      password: 'test'
    })
    console.log('✅ Auth endpoint:', response.data)
    return response.data.token
  } catch (error) {
    console.log('❌ Auth endpoint (expected):', error.response?.status, error.response?.data?.error?.message)
    return null
  }
}

// Test protected endpoints with fake token
async function testProtectedEndpoints() {
  const fakeToken = 'fake.jwt.token'

  const endpoints = [
    { name: 'Persons', url: `${BASE_URL}/persons`, method: 'get' },
    { name: 'Sessions', url: `${BASE_URL}/sessions`, method: 'get' },
    { name: 'Stats', url: `${BASE_URL}/sessions/stats/summary`, method: 'get' }
  ]

  for (const endpoint of endpoints) {
    try {
      const response = await axios({
        method: endpoint.method,
        url: endpoint.url,
        headers: { Authorization: `Bearer ${fakeToken}` }
      })
      console.log(`✅ ${endpoint.name} endpoint:`, response.data)
    } catch (error) {
      console.log(`❌ ${endpoint.name} endpoint (expected auth error):`, error.response?.status)
    }
  }
}

async function main() {
  console.log('🧪 Testing Linglong Backend API Endpoints\n')

  await testHealth()
  const token = await testAuth()
  await testProtectedEndpoints()

  console.log('\n✨ API testing complete!')
}

main().catch(console.error)