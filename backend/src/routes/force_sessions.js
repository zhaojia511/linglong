const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const ForcePlateSession = require('../models/ForcePlateSession');

// @route   POST /api/force-sessions
// @desc    Create or update force plate session (sync)
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const sessionData = {
      ...req.body,
      userId: req.user._id
    };

    let session = await ForcePlateSession.findOne({
      id: req.body.id,
      userId: req.user._id
    });

    if (session) {
      session = await ForcePlateSession.findByIdAndUpdate(
        session._id,
        sessionData,
        { new: true, runValidators: true }
      );
    } else {
      session = await ForcePlateSession.create(sessionData);
    }

    res.status(201).json({ success: true, data: session });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: error.message || 'Server error' } });
  }
});

// @route   GET /api/force-sessions
// @desc    Get force plate sessions for user
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const { limit = 50, offset = 0, personId, startDate, endDate } = req.query;
    const query = { userId: req.user._id };

    if (personId) query.personId = personId;
    if (startDate || endDate) {
      query.startTime = {};
      if (startDate) query.startTime.$gte = new Date(startDate);
      if (endDate) query.startTime.$lte = new Date(endDate);
    }

    const sessions = await ForcePlateSession
      .find(query)
      .sort({ startTime: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(offset));

    const total = await ForcePlateSession.countDocuments(query);

    res.json({ success: true, count: sessions.length, total, data: sessions });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

// @route   GET /api/force-sessions/:id
// @desc    Get force plate session by ID
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const session = await ForcePlateSession.findOne({
      id: req.params.id,
      userId: req.user._id
    });

    if (!session) {
      return res.status(404).json({ error: { message: 'Session not found' } });
    }

    res.json({ success: true, data: session });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

// @route   DELETE /api/force-sessions/:id
// @desc    Delete force plate session
// @access  Private
router.delete('/:id', protect, async (req, res) => {
  try {
    const session = await ForcePlateSession.findOne({
      id: req.params.id,
      userId: req.user._id
    });

    if (!session) {
      return res.status(404).json({ error: { message: 'Session not found' } });
    }

    await ForcePlateSession.findByIdAndDelete(session._id);
    res.json({ success: true, message: 'Session deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

module.exports = router;
