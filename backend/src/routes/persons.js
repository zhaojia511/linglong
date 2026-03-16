const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const supabase = require('../lib/supabaseClient');

// @route   POST /api/persons
// @desc    Create or update person profile
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const personData = {
      ...req.body,
      user_id: req.user.id // supabase uses snake_case
    };

    const { data, error } = await supabase
      .from('persons')
      .upsert(personData, { onConflict: 'id' })
      .select()
      .single();

    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    res.status(200).json({ success: true, data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: error.message || 'Server error' } });
  }
});

// @route   GET /api/persons
// @desc    Get all persons for the authenticated user
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    // Support optional query params: role (e.g., 'athlete') and all=true to list across users
    const { role, all } = req.query || {}
    let query = supabase.from('persons').select('*')

    if (role) {
      query = query.eq('role', role)
    }

    // By default restrict to authenticated user's records. If all=true is provided,
    // return across users (use carefully; consider restricting to admins in future).
    if (!all || all !== 'true') {
      query = query.eq('user_id', req.user.id)
    }

    const { data, error } = await query;

    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    res.json({ success: true, count: data.length, data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

// @route   GET /api/persons/:id
// @desc    Get single person by ID
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('persons')
      .select('*')
      .eq('id', req.params.id)
      .eq('user_id', req.user.id)
      .single();

    if (error && error.code === 'PGRST116') {
      return res.status(404).json({ error: { message: 'Person not found' } });
    }
    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    res.json({ success: true, data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

module.exports = router;
