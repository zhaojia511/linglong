const GMT_PLUS_8_TIME_ZONE = 'Asia/Shanghai'

function getDate(value) {
  if (!value) return null
  const date = value instanceof Date ? value : new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

function getParts(value, options) {
  const date = getDate(value)
  if (!date) return null

  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: GMT_PLUS_8_TIME_ZONE,
    hour12: false,
    ...options,
  })

  return formatter.formatToParts(date).reduce((parts, part) => {
    if (part.type !== 'literal') {
      parts[part.type] = part.value
    }
    return parts
  }, {})
}

export function formatDateGMT8(value) {
  const parts = getParts(value, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
  if (!parts) return ''
  return `${parts.year}-${parts.month}-${parts.day}`
}

export function formatTimeGMT8(value, { seconds = true } = {}) {
  const parts = getParts(value, {
    hour: '2-digit',
    minute: '2-digit',
    ...(seconds ? { second: '2-digit' } : {}),
  })
  if (!parts) return ''
  return seconds
    ? `${parts.hour}:${parts.minute}:${parts.second}`
    : `${parts.hour}:${parts.minute}`
}

export function formatDateTimeGMT8(value, { seconds = true } = {}) {
  const date = formatDateGMT8(value)
  const time = formatTimeGMT8(value, { seconds })
  if (!date || !time) return ''
  return `${date} ${time}`
}

export function formatMonthLabelGMT8(value) {
  const date = getDate(value)
  if (!date) return ''
  return new Intl.DateTimeFormat('en-US', {
    timeZone: GMT_PLUS_8_TIME_ZONE,
    year: 'numeric',
    month: 'short',
  }).format(date)
}

export function formatMonthKeyGMT8(value) {
  const parts = getParts(value, {
    year: 'numeric',
    month: '2-digit',
  })
  if (!parts) return ''
  return `${parts.year}-${parts.month}`
}