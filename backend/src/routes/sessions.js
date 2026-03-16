const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const TrainingSession = require('../models/TrainingSession');

// @route   POST /api/sessions
// @desc    Create a new training session
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const sessionData = {
      ...req.body,
      userId: req.user._id
    };

    // Check if session already exists (for sync)
    let session = await TrainingSession.findOne({ 
      id: req.body.id, 
      userId: req.user._id 
    });

    if (session) {
      // Update existing session
      session = await TrainingSession.findByIdAndUpdate(
        session._id,
        sessionData,
        { new: true, runValidators: true }
      );
    } else {
      // Create new session
      session = await TrainingSession.create(sessionData);
    }

    res.status(201).json({
      success: true,
      data: session
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: error.message || 'Server error' }
    });
  }
});

// @route   GET /api/sessions
// @desc    Get all training sessions for the authenticated user
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const { limit = 50, offset = 0, personId, startDate, endDate } = req.query;

    const query = { userId: req.user._id };

    if (personId) {
      query.personId = personId;
    }

    if (startDate || endDate) {
      query.startTime = {};
      if (startDate) query.startTime.$gte = new Date(startDate);
      if (endDate) query.startTime.$lte = new Date(endDate);
    }

    const sessions = await TrainingSession
      .find(query)
      .sort({ startTime: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(offset));

    const total = await TrainingSession.countDocuments(query);

    res.json({
      success: true,
      count: sessions.length,
      total,
      data: sessions
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: 'Server error' }
    });
  }
});

// @route   GET /api/sessions/stats/summary
// @desc    Get training statistics summary
// @access  Private
router.get('/stats/summary', protect, async (req, res) => {
  try {
    const { startDate, endDate, personId } = req.query;

    const query = { userId: req.user._id };
    if (personId) query.personId = personId;
    if (startDate || endDate) {
      query.startTime = {};
      if (startDate) query.startTime.$gte = new Date(startDate);
      if (endDate) query.startTime.$lte = new Date(endDate);
    }

    const sessions = await TrainingSession.find(query);

    const stats = {
      totalSessions: sessions.length,
      totalDuration: sessions.reduce((sum, s) => sum + s.duration, 0),
      totalCalories: sessions.reduce((sum, s) => sum + (s.calories || 0), 0),
      avgHeartRate: 0,
      maxHeartRate: 0,
      trainingTypes: {}
    };

    const validHRSessions = sessions.filter(s => s.avgHeartRate);
    if (validHRSessions.length > 0) {
      stats.avgHeartRate = Math.round(
        validHRSessions.reduce((sum, s) => sum + s.avgHeartRate, 0) / validHRSessions.length
      );
      stats.maxHeartRate = Math.max(...sessions.map(s => s.maxHeartRate || 0));
    }

    sessions.forEach(s => {
      stats.trainingTypes[s.trainingType] = (stats.trainingTypes[s.trainingType] || 0) + 1;
    });

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: 'Server error' }
    });
  }
});

// @route   GET /api/sessions/:id
// @desc    Get single training session by ID
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const session = await TrainingSession.findOne({
      id: req.params.id,
      userId: req.user._id
    });

    if (!session) {
      return res.status(404).json({
        error: { message: 'Training session not found' }
      });
    }

    res.json({
      success: true,
      data: session
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: 'Server error' }
    });
  }
});

// @route   DELETE /api/sessions/:id
// @desc    Delete a training session
// @access  Private
router.delete('/:id', protect, async (req, res) => {
  try {
    const session = await TrainingSession.findOne({ 
      id: req.params.id, 
      userId: req.user._id 
    });

    if (!session) {
      return res.status(404).json({
        error: { message: 'Training session not found' }
      });
    }

    await TrainingSession.findByIdAndDelete(session._id);

    res.json({
      success: true,
      message: 'Training session deleted'
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: 'Server error' }
    });
  }
});

module.exports = router;
