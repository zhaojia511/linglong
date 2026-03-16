import React from 'react'
import { getZoneBoundaries, calcZoneDistribution } from '../lib/trainingZones'

/**
 * Props:
 *   maxHR: number (person's max heart rate)
 *   hrData: Array<{ heartRate: number }> (raw HR data points from session)
 *   avgHR: number (optional, shown if no hrData)
 */
export default function TrainingZonesChart({ maxHR, hrData, avgHR }) {
  if (!maxHR) {
    return (
      <div style={{ padding: '15px', color: '#666', fontStyle: 'italic' }}>
        Max heart rate not set for this person. Set it in Persons to see zone breakdown.
      </div>
    )
  }

  const zones = getZoneBoundaries(maxHR)
  const distribution = hrData?.length > 0 ? calcZoneDistribution(hrData, maxHR) : null

  return (
    <div>
      <h3 style={{ marginBottom: '15px' }}>Training Zones (Max HR: {maxHR} bpm)</h3>

      <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '20px', fontSize: '14px' }}>
        <thead>
          <tr style={{ background: '#f8f9fa' }}>
            <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>Zone</th>
            <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>Name</th>
            <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>HR Range</th>
            {distribution && (
              <th style={{ padding: '8px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>Time %</th>
            )}
          </tr>
        </thead>
        <tbody>
          {zones.map((z, i) => {
            const dist = distribution?.[i]
            return (
              <tr key={z.zone}>
                <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>
                  <span style={{
                    display: 'inline-block', width: 12, height: 12,
                    background: z.color, borderRadius: 2, marginRight: 6
                  }} />
                  Zone {z.zone}
                </td>
                <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>{z.name}</td>
                <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>{z.range}</td>
                {distribution && (
                  <td style={{ padding: '8px', borderBottom: '1px solid #dee2e6' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{
                        width: `${dist.percentage * 2}px`, height: 12,
                        background: z.color, borderRadius: 2, minWidth: 2
                      }} />
                      {dist.percentage}%
                    </div>
                  </td>
                )}
              </tr>
            )
          })}
        </tbody>
      </table>

      {avgHR && !distribution && (
        <p style={{ fontSize: '13px', color: '#666' }}>
          Avg HR {avgHR} bpm — zone breakdown requires raw HR data from mobile app sync.
        </p>
      )}
    </div>
  )
}
