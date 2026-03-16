const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const supabase = require('../lib/supabaseClient');

// @route   POST /api/sessions
// @desc    Create a new training session
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const sessionData = {
      ...req.body,
      user_id: req.user.id // supabase column uses snake_case
    };

    // Upsert based on natural id + user
    const { data, error } = await supabase
      .from('training_sessions')
      .upsert(sessionData, { onConflict: 'id' })
      .select()
      .single();

    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    res.status(201).json({ success: true, data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: error.message || 'Server error' } });
  }
});

// @route   GET /api/sessions
// @desc    Get all training sessions for the authenticated user
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const { limit = 50, offset = 0, personId, startDate, endDate } = req.query;

    const pageLimit = parseInt(limit);
    const pageOffset = parseInt(offset);

    let query = supabase
      .from('training_sessions')
      .select('*', { count: 'exact' })
      .eq('user_id', req.user.id)
      .order('start_time', { ascending: false })
      .range(pageOffset, pageOffset + pageLimit - 1);

    if (personId) query = query.eq('person_id', personId);
    if (startDate) query = query.gte('start_time', startDate);
    if (endDate) query = query.lte('start_time', endDate);

    const { data, count, error } = await query;

    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    res.json({
      success: true,
      count: data.length,
      total: count,
      data
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

// @route   GET /api/sessions/stats/summary
// @desc    Get training statistics summary
// @access  Private
router.get('/stats/summary', protect, async (req, res) => {
  try {
    const { startDate, endDate, personId } = req.query;

    let query = supabase
      .from('training_sessions')
      .select('*')
      .eq('user_id', req.user.id);

    if (personId) query = query.eq('person_id', personId);
    if (startDate) query = query.gte('start_time', startDate);
    if (endDate) query = query.lte('start_time', endDate);

    const { data: sessions, error } = await query;
    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    const stats = {
      totalSessions: sessions.length,
      totalDuration: sessions.reduce((sum, s) => sum + (s.duration || 0), 0),
      totalCalories: sessions.reduce((sum, s) => sum + (s.calories || 0), 0),
      avgHeartRate: 0,
      maxHeartRate: 0,
      trainingTypes: {}
    };

    const validHRSessions = sessions.filter(s => s.avg_heart_rate);
    if (validHRSessions.length > 0) {
      stats.avgHeartRate = Math.round(
        validHRSessions.reduce((sum, s) => sum + s.avg_heart_rate, 0) / validHRSessions.length
      );
      stats.maxHeartRate = Math.max(...sessions.map(s => s.max_heart_rate || 0));
    }

    sessions.forEach(s => {
      const type = s.training_type;
      stats.trainingTypes[type] = (stats.trainingTypes[type] || 0) + 1;
    });

    res.json({ success: true, data: stats });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

// @route   GET /api/sessions/:id
// @desc    Get single training session by ID
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('training_sessions')
      .select('*')
      .eq('id', req.params.id)
      .eq('user_id', req.user.id)
      .single();

    if (error && error.code === 'PGRST116') {
      return res.status(404).json({ error: { message: 'Training session not found' } });
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

// @route   DELETE /api/sessions/:id
// @desc    Delete a training session
// @access  Private
router.delete('/:id', protect, async (req, res) => {
  try {
    const { error } = await supabase
      .from('training_sessions')
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', req.user._id);

    if (error) {
      return res.status(500).json({ error: { message: error.message } });
    }

    res.json({ success: true, message: 'Training session deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

module.exports = router;
