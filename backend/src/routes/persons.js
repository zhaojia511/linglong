const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Person = require('../models/Person');

// @route   POST /api/persons
// @desc    Create or update person profile
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const personData = {
      ...req.body,
      userId: req.user._id
    };

    // Check if person already exists
    let person = await Person.findOne({ id: req.body.id, userId: req.user._id });

    if (person) {
      // Update existing person
      person = await Person.findByIdAndUpdate(
        person._id,
        personData,
        { new: true, runValidators: true }
      );
    } else {
      // Create new person
      person = await Person.create(personData);
    }

    res.status(200).json({
      success: true,
      data: person
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: error.message || 'Server error' }
    });
  }
});

// @route   GET /api/persons
// @desc    Get all persons for the authenticated user
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const persons = await Person.find({ userId: req.user._id });

    res.json({
      success: true,
      count: persons.length,
      data: persons
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: 'Server error' }
    });
  }
});

// @route   GET /api/persons/:id
// @desc    Get single person by ID
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const person = await Person.findOne({ 
      id: req.params.id, 
      userId: req.user._id 
    });

    if (!person) {
      return res.status(404).json({
        error: { message: 'Person not found' }
      });
    }

    res.json({
      success: true,
      data: person
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: { message: 'Server error' }
    });
  }
});

module.exports = router;
