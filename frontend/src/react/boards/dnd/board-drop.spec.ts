import { resolveBoardDropTarget } from './board-drop';

describe('board drop model', () => {
  const target = {
    queryId: '12',
    order: ['1', '2', '3'],
    positions: { '1': 0, '2': 16384, '3': 32768 },
  };

  it('returns index 0 for an empty list drop', () => {
    expect(resolveBoardDropTarget(target, null)).toEqual({
      ...target,
      actionFilterValue: undefined,
      index: 0,
    });
  });

  it('returns the target card index for top-edge drops', () => {
    expect(resolveBoardDropTarget({ ...target, index: 1 }, 'top')).toEqual({
      ...target,
      actionFilterValue: undefined,
      index: 1,
    });
  });

  it('returns the next index for bottom-edge drops', () => {
    expect(resolveBoardDropTarget({ ...target, index: 1 }, 'bottom')).toEqual({
      ...target,
      actionFilterValue: undefined,
      index: 2,
    });
  });
});
