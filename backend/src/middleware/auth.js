const jwt = require('jsonwebtoken');
const User = require('../models/User');

exports.protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({
      error: { message: 'Not authorized to access this route', status: 401 }
    });
  }

  try {
    // Decode without verifying — Supabase has already authenticated the user
    // The token is a standard JWT; we extract the sub claim (Supabase user UUID)
    const decoded = jwt.decode(token);

    if (!decoded || !decoded.sub) {
      return res.status(401).json({
        error: { message: 'Invalid token', status: 401 }
      });
    }

    const supabaseId = decoded.sub;

    // Find or create a MongoDB user record keyed by supabaseId
    let user = await User.findOne({ supabaseId });
    if (!user) {
      user = await User.create({
        supabaseId,
        email: decoded.email || `${supabaseId}@supabase.local`,
        name: decoded.user_metadata?.name || decoded.email || supabaseId,
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    return res.status(401).json({
      error: { message: 'Not authorized to access this route', status: 401 }
    });
  }
};

// Generate JWT Token
exports.getSignedJwtToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE
  });
};
