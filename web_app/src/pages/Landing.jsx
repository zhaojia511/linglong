import React, { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import './Landing.css'

// Simulated athlete HR data for the hero demo
const ATHLETES = [
  { name: 'Zhang Wei', hr: 158, zone: 4, color: '#f97316' },
  { name: 'Li Jing',   hr: 142, zone: 3, color: '#22c55e' },
  { name: 'Wang Fang', hr: 171, zone: 5, color: '#ef4444' },
  { name: 'Chen Hao',  hr: 134, zone: 3, color: '#22c55e' },
  { name: 'Liu Yang',  hr: 89,  zone: 1, color: '#60a5fa' },
  { name: 'Zhao Min',  hr: 163, zone: 4, color: '#f97316' },
]

const ZONE_LABELS = { 1: 'Recovery', 2: 'Base', 3: 'Aerobic', 4: 'Threshold', 5: 'Max' }

function AthleteCard({ athlete, delay }) {
  const [hr, setHr] = useState(athlete.hr)
  const [pulse, setPulse] = useState(false)

  useEffect(() => {
    const id = setInterval(() => {
      const delta = Math.floor(Math.random() * 7) - 3
      setHr(prev => Math.max(60, Math.min(195, prev + delta)))
      setPulse(true)
      setTimeout(() => setPulse(false), 300)
    }, 1200 + delay * 150)
    return () => clearInterval(id)
  }, [delay])

  return (
    <div className="lp-athlete-card" style={{ animationDelay: `${delay * 0.1}s` }}>
      <div className="lp-athlete-name">{athlete.name}</div>
      <div className={`lp-athlete-hr ${pulse ? 'lp-pulse' : ''}`} style={{ color: athlete.color }}>
        {hr}
      </div>
      <div className="lp-athlete-bpm">bpm</div>
      <div className="lp-athlete-zone" style={{ background: athlete.color + '22', color: athlete.color }}>
        Z{athlete.zone} {ZONE_LABELS[athlete.zone]}
      </div>
    </div>
  )
}

export default function Landing() {
  const featuresRef = useRef(null)

  const scrollToFeatures = (e) => {
    e.preventDefault()
    featuresRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <div className="lp">
      {/* Nav */}
      <nav className="lp-nav">
        <div className="lp-nav-inner">
          <span className="lp-logo">
            <span className="lp-logo-icon">♥</span> Linglong
          </span>
          <div className="lp-nav-links">
            <a href="#features" onClick={scrollToFeatures}>Features</a>
            <Link to="/login" className="lp-nav-cta">Sign in</Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="lp-hero">
        <div className="lp-hero-text">
          <div className="lp-hero-badge">Built for team sports coaching</div>
          <h1 className="lp-hero-headline">
            Your whole team's<br />
            heart rate,<br />
            <span className="lp-accent">live on one screen.</span>
          </h1>
          <p className="lp-hero-sub">
            Connect BLE chest straps, assign sensors to athletes, and monitor every
            heartbeat in real time — no wires, no complexity.
          </p>
          <div className="lp-hero-actions">
            <a href="#features" onClick={scrollToFeatures} className="lp-btn-primary">
              See features
            </a>
            <Link to="/login" className="lp-btn-ghost">
              Open app →
            </Link>
          </div>
        </div>

        <div className="lp-hero-demo">
          <div className="lp-demo-label">Live session · 6 athletes</div>
          <div className="lp-demo-grid">
            {ATHLETES.map((a, i) => (
              <AthleteCard key={a.name} athlete={a} delay={i} />
            ))}
          </div>
          <div className="lp-demo-footer">
            <span className="lp-demo-dot lp-demo-dot--green" /> BLE connected · recording
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="lp-features" id="features" ref={featuresRef}>
        <div className="lp-section-inner">
          <h2 className="lp-section-title">Everything a coach needs</h2>
          <p className="lp-section-sub">No subscription hardware. No proprietary dongles. Just standard BLE chest straps and your phone.</p>
          <div className="lp-features-grid">
            <FeatureCard
              icon="📡"
              title="Multi-sensor BLE"
              desc="Connect up to 10+ BLE chest strap sensors simultaneously. Industry-standard ANT+/BLE HR profiles."
            />
            <FeatureCard
              icon="👥"
              title="Athlete assignment"
              desc="Tap any sensor card to assign it to an athlete. Reassign on the fly between drills."
            />
            <FeatureCard
              icon="📈"
              title="HRV analysis"
              desc="RMSSD, Poincaré plot, rolling fatigue trend, and acute training-context interpretation per session."
            />
            <FeatureCard
              icon="🗂️"
              title="Session history"
              desc="Full training archive with avg/max/min HR, duration, and session type. Filterable by athlete group and category."
            />
            <FeatureCard
              icon="☁️"
              title="Cloud sync"
              desc="Sessions sync automatically to Supabase. Access history from the web dashboard anywhere."
            />
            <FeatureCard
              icon="🔒"
              title="Your data"
              desc="You own your database. Hosted on your Supabase project — no third-party data sharing."
            />
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="lp-how">
        <div className="lp-section-inner">
          <h2 className="lp-section-title">Up in three steps</h2>
          <div className="lp-steps">
            <Step n="1" title="Pair sensors" desc="Open the app and let it scan for nearby BLE HR chest straps. Tap to connect." />
            <div className="lp-step-arrow">→</div>
            <Step n="2" title="Assign athletes" desc="Tap each sensor card and pick an athlete from your roster. Done in seconds." />
            <div className="lp-step-arrow">→</div>
            <Step n="3" title="Start session" desc="Hit record. Monitor live HR, get instant alerts, and review full analytics after." />
          </div>
        </div>
      </section>

      {/* Stats bar */}
      <section className="lp-stats">
        <div className="lp-section-inner">
          <div className="lp-stats-row">
            <Stat value="Real-time" label="BLE monitoring" />
            <Stat value="10+" label="Simultaneous sensors" />
            <Stat value="5" label="HRV metrics per session" />
            <Stat value="iOS + Android" label="Cross-platform" />
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="lp-cta">
        <div className="lp-section-inner lp-cta-inner">
          <h2>Ready to see it in action?</h2>
          <p>Sign in to the web dashboard or build from source for iOS/Android.</p>
          <div className="lp-hero-actions">
            <Link to="/login" className="lp-btn-primary">Open web app</Link>
            <a
              href="https://github.com"
              className="lp-btn-ghost"
              target="_blank"
              rel="noreferrer"
            >
              View source
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="lp-footer">
        <span className="lp-logo"><span className="lp-logo-icon">♥</span> Linglong</span>
        <span>Heart rate monitoring for team sports coaching.</span>
      </footer>
    </div>
  )
}

function FeatureCard({ icon, title, desc }) {
  return (
    <div className="lp-feature-card">
      <div className="lp-feature-icon">{icon}</div>
      <h3>{title}</h3>
      <p>{desc}</p>
    </div>
  )
}

function Step({ n, title, desc }) {
  return (
    <div className="lp-step">
      <div className="lp-step-n">{n}</div>
      <h3>{title}</h3>
      <p>{desc}</p>
    </div>
  )
}

function Stat({ value, label }) {
  return (
    <div className="lp-stat">
      <div className="lp-stat-value">{value}</div>
      <div className="lp-stat-label">{label}</div>
    </div>
  )
}
