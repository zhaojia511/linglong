import React, { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { QueryClientProvider } from '@tanstack/react-query'
import Login from './pages/Login'
import ResetPassword from './pages/ResetPassword'
import Dashboard from './pages/Dashboard'
import Sessions from './pages/Sessions'
import SessionDetail from './pages/SessionDetail'
import PersonsManagement from './pages/PersonsManagement'
import RecordingManagement from './pages/RecordingManagement'
import HistoryAnalysis from './pages/HistoryAnalysis'
import Settings from './pages/Settings'
import { authService } from './services/api'
import { supabase } from './services/supabaseClient'
import { queryClient } from './lib/queryClient'
import Header from './components/Header'
import TabSidebar from './components/TabSidebar'

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [authChecked, setAuthChecked] = useState(false)

  useEffect(() => {
    // Check current session
    authService.isAuthenticated().then((authed) => {
      setIsAuthenticated(authed)
      setAuthChecked(true)
    })

    // Subscribe to future auth changes (token refresh, logout from another tab)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setIsAuthenticated(!!session)
      setAuthChecked(true)
    })

    return () => subscription.unsubscribe()
  }, [])

  const PrivateRoute = ({ children }) => {
    if (!authChecked) return <div className="container">Loading...</div>
    return isAuthenticated ? children : <Navigate to="/login" />
  }

  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <div className="app-layout">
          <Header />
          <TabSidebar />
          <main className="main-content">
            <Routes>
              <Route path="/login" element={<Login onLogin={() => setIsAuthenticated(true)} />} />
              <Route path="/reset-password" element={<ResetPassword />} />
              <Route
                path="/"
                element={
                  <PrivateRoute>
                    <Dashboard />
                  </PrivateRoute>
                }
              />
              <Route
                path="/sessions"
                element={
                  <PrivateRoute>
                    <Sessions />
                  </PrivateRoute>
                }
              />
              <Route path="/sessions/:id" element={<PrivateRoute><SessionDetail /></PrivateRoute>} />
              <Route path="/persons" element={<PrivateRoute><PersonsManagement /></PrivateRoute>} />
              <Route path="/recordings" element={<PrivateRoute><RecordingManagement /></PrivateRoute>} />
              <Route path="/analysis" element={<PrivateRoute><HistoryAnalysis /></PrivateRoute>} />
              <Route path="/settings" element={<PrivateRoute><Settings /></PrivateRoute>} />
              <Route path="*" element={<Navigate to="/" />} />
            </Routes>
          </main>
        </div>
      </Router>
    </QueryClientProvider>
  )
}

export default App
