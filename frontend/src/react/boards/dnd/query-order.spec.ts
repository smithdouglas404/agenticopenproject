import { buildInsertDelta, buildRemoveDelta } from './query-order';

describe('query-order helpers', () => {
  const list = {
    order: ['1', '2', '3'],
    positions: { '1': 0, '2': 16384, '3': 32768 },
  };

  it('builds an insert delta for a target index', () => {
    expect(buildInsertDelta({
      list,
      wpId: '9',
      toIndex: 1,
    })).toEqual({ '9': 8192 });
  });

  it('builds a remove delta for a source query', () => {
    expect(buildRemoveDelta('9')).toEqual({ '9': -1 });
  });

  it('builds a reorder delta for same-list moves', () => {
    expect(buildInsertDelta({
      list,
      wpId: '1',
      toIndex: 2,
      fromIndex: 0,
    })).toEqual({ '1': 40960, '2': 0 });
  });
});
