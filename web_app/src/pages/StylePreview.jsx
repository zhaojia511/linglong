import React from 'react'
import './StylePreview.css'

function StylePreview() {
  const sampleData = {
    totalSessions: 24,
    avgHeartRate: 145,
    totalCalories: 3280
  }

  return (
    <div className="style-preview-container">
      <h1 className="page-title">Choose Your UI Style</h1>
      <p style={{ marginBottom: '24px', color: '#666' }}>
        Preview different design styles below and choose your favorite
      </p>

      {/* Style 1: Minimal Clean */}
      <div className="style-section">
        <h2 className="style-heading">Style 1: Minimal Clean</h2>
        <p className="style-description">Clean white cards with subtle shadows, minimal borders</p>
        <div className="style-demo style-1">
          <div className="demo-stats-grid">
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Sessions</div>
              <div className="demo-stat-value">{sampleData.totalSessions}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Avg Heart Rate</div>
              <div className="demo-stat-value">{sampleData.avgHeartRate}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Calories</div>
              <div className="demo-stat-value">{sampleData.totalCalories}</div>
            </div>
          </div>
          <div className="demo-card">
            <h3>Sample Card</h3>
            <p>This is what your content cards will look like.</p>
            <button className="demo-btn">Action Button</button>
          </div>
        </div>
      </div>

      {/* Style 2: Bordered */}
      <div className="style-section">
        <h2 className="style-heading">Style 2: Bordered</h2>
        <p className="style-description">Defined borders, no shadows, flat design</p>
        <div className="style-demo style-2">
          <div className="demo-stats-grid">
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Sessions</div>
              <div className="demo-stat-value">{sampleData.totalSessions}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Avg Heart Rate</div>
              <div className="demo-stat-value">{sampleData.avgHeartRate}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Calories</div>
              <div className="demo-stat-value">{sampleData.totalCalories}</div>
            </div>
          </div>
          <div className="demo-card">
            <h3>Sample Card</h3>
            <p>This is what your content cards will look like.</p>
            <button className="demo-btn">Action Button</button>
          </div>
        </div>
      </div>

      {/* Style 3: Soft */}
      <div className="style-section">
        <h2 className="style-heading">Style 3: Soft</h2>
        <p className="style-description">Rounded corners, light background, gentle shadows</p>
        <div className="style-demo style-3">
          <div className="demo-stats-grid">
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Sessions</div>
              <div className="demo-stat-value">{sampleData.totalSessions}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Avg Heart Rate</div>
              <div className="demo-stat-value">{sampleData.avgHeartRate}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Calories</div>
              <div className="demo-stat-value">{sampleData.totalCalories}</div>
            </div>
          </div>
          <div className="demo-card">
            <h3>Sample Card</h3>
            <p>This is what your content cards will look like.</p>
            <button className="demo-btn">Action Button</button>
          </div>
        </div>
      </div>

      {/* Style 4: Material */}
      <div className="style-section">
        <h2 className="style-heading">Style 4: Material</h2>
        <p className="style-description">Card elevation with prominent shadows, colored accents</p>
        <div className="style-demo style-4">
          <div className="demo-stats-grid">
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Sessions</div>
              <div className="demo-stat-value">{sampleData.totalSessions}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Avg Heart Rate</div>
              <div className="demo-stat-value">{sampleData.avgHeartRate}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Calories</div>
              <div className="demo-stat-value">{sampleData.totalCalories}</div>
            </div>
          </div>
          <div className="demo-card">
            <h3>Sample Card</h3>
            <p>This is what your content cards will look like.</p>
            <button className="demo-btn">Action Button</button>
          </div>
        </div>
      </div>

      {/* Style 5: Compact Dark Accents */}
      <div className="style-section">
        <h2 className="style-heading">Style 5: Compact Dark Accents</h2>
        <p className="style-description">Tight spacing, dark headers, subtle highlights</p>
        <div className="style-demo style-5">
          <div className="demo-stats-grid">
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Sessions</div>
              <div className="demo-stat-value">{sampleData.totalSessions}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Avg Heart Rate</div>
              <div className="demo-stat-value">{sampleData.avgHeartRate}</div>
            </div>
            <div className="demo-stat-card">
              <div className="demo-stat-label">Total Calories</div>
              <div className="demo-stat-value">{sampleData.totalCalories}</div>
            </div>
          </div>
          <div className="demo-card">
            <h3>Sample Card</h3>
            <p>This is what your content cards will look like.</p>
            <button className="demo-btn">Action Button</button>
          </div>
        </div>
      </div>

      <div style={{ marginTop: '40px', padding: '20px', background: '#f0f0f0', borderRadius: '8px' }}>
        <h3>How to choose:</h3>
        <p>Tell me which style number you prefer (1-5), and I'll apply it to your entire application.</p>
      </div>
    </div>
  )
}

export default StylePreview
