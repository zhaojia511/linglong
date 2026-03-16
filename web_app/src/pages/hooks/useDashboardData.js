import { useQuery } from '@tanstack/react-query'
import { sessionService } from '../../services/api'

export function useDashboardData() {
  const statsQuery = useQuery({
    queryKey: ['dashboard', 'stats'],
    queryFn: async () => {
      const data = await sessionService.getStats()
      return data.data || data
    },
    retry: 1,
    staleTime: 30000,
  })

  const sessionsQuery = useQuery({
    queryKey: ['dashboard', 'recentSessions'],
    queryFn: async () => {
      const data = await sessionService.getSessions({ limit: 5 })
      return data.data || data || []
    },
    retry: 1,
    staleTime: 30000,
  })

  return { statsQuery, sessionsQuery }
}
