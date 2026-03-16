const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const supabase = require('../lib/supabaseClient');

// @route   POST /api/auth/register
// @desc    Register a new user (Supabase Auth)
// @access  Public
router.post('/register', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('name').notEmpty().withMessage('Name is required')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { email, password, name } = req.body;

    // Create user via Supabase Admin API; auto-confirm email to simplify dev
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name }
    });

    if (error) {
      return res.status(400).json({ error: { message: error.message } });
    }

    res.status(201).json({
      success: true,
      user: {
        id: data.user.id,
        email: data.user.email,
        name: data.user.user_metadata?.name || name
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

// @route   POST /api/auth/login
// @desc    Login user (Supabase Auth)
// @access  Public
router.post('/login', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      return res.status(401).json({ error: { message: error.message } });
    }

    res.json({
      success: true,
      token: data.session?.access_token,
      refresh_token: data.session?.refresh_token,
      user: {
        id: data.user.id,
        email: data.user.email,
        name: data.user.user_metadata?.name,
        role: data.user.app_metadata?.role || 'user'
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { message: 'Server error' } });
  }
});

module.exports = router;
