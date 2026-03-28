import { useMutation, useQueryClient } from '@tanstack/react-query';
import { saveBoard } from '../api/boards';
import type { GridWidget } from '../api/types';

interface SaveBoardVars {
  boardId: number;
  widgets: GridWidget[];
}

export function useSaveBoard() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ boardId, widgets }: SaveBoardVars) =>
      saveBoard(boardId, widgets),
    onSuccess: (_data, { boardId }) => {
      queryClient.invalidateQueries({ queryKey: ['board', boardId] });
    },
  });
}
