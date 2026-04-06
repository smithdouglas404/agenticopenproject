import type { BoardGrid } from '../api/types';

export function isReactBoardSupported(board:BoardGrid):boolean {
  return board.options.type === 'free'
    || (board.options.type === 'action' && board.options.attribute === 'status');
}
