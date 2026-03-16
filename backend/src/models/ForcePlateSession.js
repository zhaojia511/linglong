const mongoose = require('mongoose');

const ForceSampleSchema = new mongoose.Schema({
  timestamp: { type: Date, required: true },
  channel1: { type: Number, required: true },
  channel2: { type: Number, required: true },
  channel3: { type: Number, required: true },
  channel4: { type: Number, required: true },
  deviceId: { type: String }
}, { _id: false });

const ForcePlateSessionSchema = new mongoose.Schema({
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
  testType: {
    type: String,
    required: true,
    enum: ['jumping', 'balance', 'gait', 'custom']
  },
  avgForce: { type: Number, min: 0 },
  maxForce: { type: Number, min: 0 },
  minForce: { type: Number, min: 0 },
  peakImpulse: { type: Number, min: 0 },
  samples: { type: [ForceSampleSchema], default: [] },
  notes: { type: String },
  metadata: { type: mongoose.Schema.Types.Mixed }
});

ForcePlateSessionSchema.index({ userId: 1, startTime: -1 });
ForcePlateSessionSchema.index({ personId: 1, startTime: -1 });

module.exports = mongoose.model('ForcePlateSession', ForcePlateSessionSchema);
