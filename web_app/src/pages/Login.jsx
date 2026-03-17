import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { authService } from '../services/api'

function Login({ onLogin }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isRegister, setIsRegister] = useState(false)
  const [isForgotPassword, setIsForgotPassword] = useState(false)
  const [name, setName] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setSuccess('')
    setLoading(true)

    try {
      if (isForgotPassword) {
        const result = await authService.resetPassword(email)
        setSuccess(result.message)
        setIsForgotPassword(false)
      } else if (isRegister) {
        await authService.register(email, password, name)
        setSuccess('Registration successful! Please check your email to verify your account, then log in.')
        setIsRegister(false)
      } else {
        await authService.login(email, password)
        onLogin()
        navigate('/')
      }
    } catch (err) {
      setError(err?.message || err?.response?.data?.error?.message || 'An error occurred')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-form">
      <h2>{isForgotPassword ? 'Reset Password' : isRegister ? 'Register' : 'Login'}</h2>
      <form onSubmit={handleSubmit}>
        {isRegister && !isForgotPassword && (
          <div className="form-group">
            <label>Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </div>
        )}
        <div className="form-group">
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        {!isForgotPassword && (
          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={6}
            />
          </div>
        )}
        {error && <div className="error">{error}</div>}
        {success && <div className="success">{success}</div>}
        <button type="submit" className="btn btn-primary" disabled={loading}>
          {loading ? 'Loading...' : isForgotPassword ? 'Send Reset Email' : isRegister ? 'Register' : 'Login'}
        </button>
      </form>
      
      {!isForgotPassword && (
        <div className="auth-links">
          <button 
            type="button" 
            className="link-btn"
            onClick={() => setIsForgotPassword(true)}
          >
            Forgot Password?
          </button>
        </div>
      )}
      
      <div className="auth-links">
        <button 
          type="button" 
          className="link-btn"
          onClick={() => {
            setIsRegister(!isRegister)
            setIsForgotPassword(false)
            setError('')
            setSuccess('')
          }}
        >
          {isRegister ? 'Already have an account? Login' : "Don't have an account? Register"}
        </button>
        {isForgotPassword && (
          <button 
            type="button" 
            className="link-btn"
            onClick={() => {
              setIsForgotPassword(false)
              setError('')
              setSuccess('')
            }}
          >
            Back to Login
          </button>
        )}
      </div>

    </div>
  )
}

export default Login
