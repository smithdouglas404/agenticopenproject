import { apiFetch } from './client';
import type { BoardGrid, GridWidget } from './types';

export async function fetchBoard(boardId: number): Promise<BoardGrid> {
  return apiFetch<BoardGrid>(`/grids/${boardId}`);
}

export async function saveBoard(
  boardId: number,
  widgets: GridWidget[],
): Promise<BoardGrid> {
  return apiFetch<BoardGrid>(`/grids/${boardId}`, {
    method: 'PATCH',
    body: JSON.stringify({ widgets }),
  });
}
