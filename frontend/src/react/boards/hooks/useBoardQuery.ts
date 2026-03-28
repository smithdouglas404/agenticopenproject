import { useQuery } from '@tanstack/react-query';
import { fetchBoard } from '../api/boards';
import type { BoardGrid } from '../api/types';

export function useBoardQuery(boardId: number) {
  return useQuery<BoardGrid>({
    queryKey: ['board', boardId],
    queryFn: () => fetchBoard(boardId),
    staleTime: 30_000,
  });
}
