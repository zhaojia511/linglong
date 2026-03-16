const mongoose = require('mongoose');

const PersonSchema = new mongoose.Schema({
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
  name: {
    type: String,
    required: [true, 'Please provide a name']
  },
  age: {
    type: Number,
    required: [true, 'Please provide age'],
    min: 1,
    max: 120
  },
  gender: {
    type: String,
    required: true,
    enum: ['male', 'female', 'other']
  },
  weight: {
    type: Number,
    required: [true, 'Please provide weight'],
    min: 20,
    max: 300
  },
  height: {
    type: Number,
    required: [true, 'Please provide height'],
    min: 50,
    max: 250
  },
  maxHeartRate: {
    type: Number,
    min: 60,
    max: 220
  },
  restingHeartRate: {
    type: Number,
    min: 30,
    max: 100
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

PersonSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('Person', PersonSchema);
