/**
 * Export training sessions to TCX and GPX formats.
 * TCX (Training Center XML) — standard for HR-only sessions, supported by Garmin/Strava.
 * GPX (GPS Exchange Format) — standard for GPS track data with HR extensions.
 */

/**
 * Export a single session to TCX format.
 * @param {object} session - session object from Supabase
 * @param {string} [athleteName] - optional athlete name
 */
export function exportTCX(session, athleteName = '') {
  const startTime = new Date(session.startTime).toISOString()
  const endTime = session.endTime ? new Date(session.endTime).toISOString() : startTime
  const sportMap = {
    running: 'Running',
    cycling: 'Biking',
    swimming: 'Other',
    gym: 'Other',
    general: 'Other',
    other: 'Other',
  }
  const sport = sportMap[session.trainingType] ?? 'Other'

  const trackpoints = (session.heartRateData ?? [])
    .map((d) => {
      const t = new Date(d.timestamp).toISOString()
      return `      <Trackpoint>
        <Time>${t}</Time>
        <HeartRateBpm><Value>${d.heartRate}</Value></HeartRateBpm>
      </Trackpoint>`
    })
    .join('\n')

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2
    http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">
  <Activities>
    <Activity Sport="${sport}">
      <Id>${startTime}</Id>
      <Lap StartTime="${startTime}">
        <TotalTimeSeconds>${session.duration ?? 0}</TotalTimeSeconds>
        <Calories>${Math.round(session.calories ?? 0)}</Calories>
        ${session.avgHeartRate ? `<AverageHeartRateBpm><Value>${session.avgHeartRate}</Value></AverageHeartRateBpm>` : ''}
        ${session.maxHeartRate ? `<MaximumHeartRateBpm><Value>${session.maxHeartRate}</Value></MaximumHeartRateBpm>` : ''}
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
        <Track>
${trackpoints}
        </Track>
      </Lap>
      ${athleteName ? `<Notes>${athleteName} - ${session.title ?? ''}</Notes>` : `<Notes>${session.title ?? ''}</Notes>`}
    </Activity>
  </Activities>
</TrainingCenterDatabase>`

  downloadFile(xml, `${slugify(session.title)}-${dateStr(session.startTime)}.tcx`, 'application/vnd.garmin.tcx+xml')
}

/**
 * Export a single session to GPX format with HR extension.
 * Note: GPX requires GPS coordinates. Since Linglong doesn't capture GPS,
 * HR data is included via the Garmin TrackPointExtension.
 * @param {object} session
 * @param {string} [athleteName]
 */
export function exportGPX(session, athleteName = '') {
  const startTime = new Date(session.startTime).toISOString()
  const name = athleteName ? `${athleteName} - ${session.title ?? ''}` : (session.title ?? 'Training Session')

  const trackpoints = (session.heartRateData ?? [])
    .map((d) => {
      const t = new Date(d.timestamp).toISOString()
      return `      <trkpt lat="0" lon="0">
        <time>${t}</time>
        <extensions>
          <gpxtpx:TrackPointExtension>
            <gpxtpx:hr>${d.heartRate}</gpxtpx:hr>
          </gpxtpx:TrackPointExtension>
        </extensions>
      </trkpt>`
    })
    .join('\n')

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Linglong HR Monitor"
  xmlns="http://www.topografix.com/GPX/1/1"
  xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.topografix.com/GPX/1/1
    http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>${name}</name>
    <time>${startTime}</time>
  </metadata>
  <trk>
    <name>${name}</name>
    <type>${session.trainingType ?? 'general'}</type>
    <trkseg>
${trackpoints}
    </trkseg>
  </trk>
</gpx>`

  downloadFile(xml, `${slugify(session.title)}-${dateStr(session.startTime)}.gpx`, 'application/gpx+xml')
}

function downloadFile(content, filename, mimeType) {
  const blob = new Blob([content], { type: mimeType })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

function slugify(str) {
  return (str ?? 'session').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

function dateStr(dateStr) {
  return new Date(dateStr).toISOString().split('T')[0]
}
