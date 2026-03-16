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
import StylePreview from './pages/StylePreview'
import { authService } from './services/api'
import { queryClient } from './lib/queryClient'
import Header from './components/Header'
import TabSidebar from './components/TabSidebar'

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [authChecked, setAuthChecked] = useState(false)

  useEffect(() => {
    let mounted = true
    authService.isAuthenticated().then((authed) => {
      if (mounted) {
        setIsAuthenticated(authed)
        setAuthChecked(true)
      }
    })
    return () => {
      mounted = false
    }
  }, [])

  const PrivateRoute = ({ children }) => {
    if (!authChecked) {
      return (
        <div className="container" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
          <div>Loading...</div>
        </div>
      )
    }
    return isAuthenticated ? children : <Navigate to="/login" />
  }

  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <div className="app-layout">
          {isAuthenticated && <Header />}
          {isAuthenticated && <TabSidebar />}
          <main className={isAuthenticated ? "main-content" : "main-content-full"}>
            <Routes>
              <Route 
                path="/login" 
                element={
                  authChecked && isAuthenticated ? <Navigate to="/" /> : <Login onLogin={() => setIsAuthenticated(true)} />
                } 
              />
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
              <Route path="/style-preview" element={<PrivateRoute><StylePreview /></PrivateRoute>} />
              <Route path="*" element={<Navigate to="/" />} />
            </Routes>
          </main>
        </div>
      </Router>
    </QueryClientProvider>
  )
}

export default App
