const supabase = require('../lib/supabaseClient');

exports.protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({
      error: {
        message: 'Not authorized to access this route',
        status: 401
      }
    });
  }

  try {
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data?.user) {
      return res.status(401).json({
        error: {
          message: 'Not authorized to access this route',
          status: 401
        }
      });
    }

    const { user } = data;
    req.user = {
      id: user.id,
      email: user.email,
      role: user.app_metadata?.role || 'user'
    };

    next();
  } catch (error) {
    return res.status(401).json({
      error: {
        message: 'Not authorized to access this route',
        status: 401
      }
    });
  }
};
