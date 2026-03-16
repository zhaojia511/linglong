const mongoose = require('mongoose');

const HeartRateDataSchema = new mongoose.Schema({
  timestamp: {
    type: Date,
    required: true
  },
  heartRate: {
    type: Number,
    required: true,
    min: 30,
    max: 250
  },
  deviceId: {
    type: String
  }
}, { _id: false });

const TrainingSessionSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
    unique: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  personId: {
    type: String,
    required: true
  },
  title: {
    type: String,
    required: [true, 'Please provide a title']
  },
  startTime: {
    type: Date,
    required: true
  },
  endTime: {
    type: Date
  },
  duration: {
    type: Number,
    required: true,
    min: 0
  },
  distance: {
    type: Number,
    min: 0
  },
  avgHeartRate: {
    type: Number,
    min: 30,
    max: 250
  },
  maxHeartRate: {
    type: Number,
    min: 30,
    max: 250
  },
  minHeartRate: {
    type: Number,
    min: 30,
    max: 250
  },
  calories: {
    type: Number,
    min: 0
  },
  trainingType: {
    type: String,
    required: true,
    enum: ['running', 'cycling', 'gym', 'swimming', 'general', 'other']
  },
  heartRateData: [HeartRateDataSchema],
  notes: {
    type: String
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Indexes for better query performance
TrainingSessionSchema.index({ userId: 1, startTime: -1 });
TrainingSessionSchema.index({ personId: 1, startTime: -1 });

module.exports = mongoose.model('TrainingSession', TrainingSessionSchema);
