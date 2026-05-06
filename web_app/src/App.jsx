import React, { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate, Outlet } from 'react-router-dom'
import { QueryClientProvider } from '@tanstack/react-query'
import Login from './pages/Login'
import ResetPassword from './pages/ResetPassword'
import Landing from './pages/Landing'
import Dashboard from './pages/Dashboard'
import Sessions from './pages/Sessions'
import SessionDetail from './pages/SessionDetail'
import PersonsManagement from './pages/PersonsManagement'
import HistoryAnalysis from './pages/HistoryAnalysis'
import ReadinessHistory from './pages/ReadinessHistory'
import Settings from './pages/Settings'
import { authService } from './services/api'
import { supabase } from './services/supabaseClient'
import { queryClient } from './lib/queryClient'
import Header from './components/Header'
import TabSidebar from './components/TabSidebar'

function AppLayout() {
  return (
    <div className="app-layout">
      <Header />
      <TabSidebar />
      <main className="main-content">
        <Outlet />
      </main>
    </div>
  )
}

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [authChecked, setAuthChecked] = useState(false)

  useEffect(() => {
    authService.isAuthenticated().then((authed) => {
      setIsAuthenticated(authed)
      setAuthChecked(true)
    })

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
        <Routes>
          {/* Public — no app chrome */}
          <Route path="/landing" element={<Landing />} />

          {/* App shell — header + sidebar via Outlet */}
          <Route element={<AppLayout />}>
            <Route path="/login" element={<Login onLogin={() => setIsAuthenticated(true)} />} />
            <Route path="/reset-password" element={<ResetPassword />} />
            <Route path="/" element={<PrivateRoute><Dashboard /></PrivateRoute>} />
            <Route path="/sessions" element={<PrivateRoute><Sessions /></PrivateRoute>} />
            <Route path="/sessions/:id" element={<PrivateRoute><SessionDetail /></PrivateRoute>} />
            <Route path="/persons" element={<PrivateRoute><PersonsManagement /></PrivateRoute>} />
            <Route path="/analysis" element={<PrivateRoute><HistoryAnalysis /></PrivateRoute>} />
            <Route path="/readiness" element={<PrivateRoute><ReadinessHistory /></PrivateRoute>} />
            <Route path="/settings" element={<PrivateRoute><Settings /></PrivateRoute>} />
            <Route path="*" element={<Navigate to="/" />} />
          </Route>
        </Routes>
      </Router>
    </QueryClientProvider>
  )
}

export default App
