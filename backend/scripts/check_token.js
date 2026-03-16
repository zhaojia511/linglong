require('dotenv').config({ path: require('path').resolve(__dirname, '..', '.env') })
const supabase = require('../src/lib/supabaseClient')

const token = process.argv[2]

if (!token) {
  console.error('Usage: node check_token.js <token>')
  process.exit(2)
}

async function run() {
  try {
    const { data, error } = await supabase.auth.getUser(token)
    if (error) {
      console.error('getUser error:', error)
      process.exit(1)
    }
    console.log('getUser success:', data)
  } catch (err) {
    console.error('Exception:', err)
    process.exit(1)
  }
}

run()
