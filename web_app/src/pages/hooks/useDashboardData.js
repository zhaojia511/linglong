import { useQuery } from '@tanstack/react-query'
import { sessionService } from '../../services/api'

export function useDashboardData() {
  const statsQuery = useQuery({
    queryKey: ['dashboard', 'stats'],
    queryFn: () => sessionService.getStats(),
  })

  const sessionsQuery = useQuery({
    queryKey: ['dashboard', 'recentSessions'],
    queryFn: () => sessionService.getSessions({ limit: 5 }),
  })

  return { statsQuery, sessionsQuery }
}
