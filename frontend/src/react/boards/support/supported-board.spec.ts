import { isReactBoardSupported } from './supported-board';
import type { BoardGrid } from '../api/types';

function buildBoard(options:BoardGrid['options']):BoardGrid {
  return {
    id: 1,
    name: 'Board',
    rowCount: 1,
    columnCount: 1,
    widgets: [],
    options,
    _links: {
      self: { href: '/api/v3/boards/1' },
    },
  };
}

describe('isReactBoardSupported', () => {
  it('supports free boards', () => {
    expect(isReactBoardSupported(buildBoard({ type: 'free' }))).toBe(true);
  });

  it('supports status action boards', () => {
    expect(isReactBoardSupported(buildBoard({ type: 'action', attribute: 'status' }))).toBe(true);
  });

  it('rejects version action boards', () => {
    expect(isReactBoardSupported(buildBoard({ type: 'action', attribute: 'version' }))).toBe(false);
  });
});
