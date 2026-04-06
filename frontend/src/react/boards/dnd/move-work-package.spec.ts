import { moveWorkPackage } from './move-work-package';
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

describe('moveWorkPackage', () => {
  const source = {
    queryId: '10',
    order: ['1', '2', '3'],
    positions: { '1': 0, '2': 16384, '3': 32768 },
    index: 0,
  };

  const target = {
    queryId: '11',
    order: ['4', '5'],
    positions: { '4': 0, '5': 16384 },
    index: 1,
  };

  it('removes from source and inserts into target on free-board cross-column moves', async () => {
    const calls:{ queryId:string; delta:Record<string, number> }[] = [];

    await moveWorkPackage({
      reorderWorkPackages: (args) => {
        calls.push(args);
        return Promise.resolve();
      },
      updateWorkPackage: () => Promise.resolve(),
    }, {
      board: buildBoard({ type: 'free' }),
      wpId: 1,
      lockVersion: 7,
      source,
      target,
      fromIndex: 0,
    });

    expect(calls).toEqual([
      { queryId: '10', delta: { '1': -1 } },
      { queryId: '11', delta: { '1': 8192 } },
    ]);
  });

  it('reorders within the same list using the computed target index', async () => {
    const reorderWorkPackages = jasmine.createSpy('reorderWorkPackages').and.resolveTo(undefined);

    await moveWorkPackage({
      reorderWorkPackages,
      updateWorkPackage: () => Promise.resolve(),
    }, {
      board: buildBoard({ type: 'free' }),
      wpId: 1,
      lockVersion: 7,
      source,
      target: { ...source, index: 2 },
      fromIndex: 0,
    });

    expect(reorderWorkPackages).toHaveBeenCalledOnceWith({
      queryId: '10',
      delta: { '1': 40960, '2': 0 },
    });
  });

  it('updates status before fixing query order on status-board cross-column moves', async () => {
    const callOrder:string[] = [];

    await moveWorkPackage({
      reorderWorkPackages: () => {
        callOrder.push('reorder');
        return Promise.resolve();
      },
      updateWorkPackage: () => {
        callOrder.push('update');
        return Promise.resolve();
      },
    }, {
      board: buildBoard({ type: 'action', attribute: 'status' }),
      wpId: 1,
      lockVersion: 7,
      source,
      target: { ...target, actionFilterValue: '9' },
      fromIndex: 0,
    });

    expect(callOrder).toEqual(['update', 'reorder', 'reorder']);
  });

  it('never tries to execute version moves', async () => {
    const reorderWorkPackages = jasmine.createSpy('reorderWorkPackages');
    const updateWorkPackage = jasmine.createSpy('updateWorkPackage');

    await expectAsync(moveWorkPackage({
      reorderWorkPackages: (...args) => Promise.resolve(reorderWorkPackages(...args)),
      updateWorkPackage: (...args) => Promise.resolve(updateWorkPackage(...args)),
    }, {
      board: buildBoard({ type: 'action', attribute: 'version' }),
      wpId: 1,
      lockVersion: 7,
      source,
      target,
      fromIndex: 0,
    })).toBeRejectedWithError('Unsupported board type');

    expect(updateWorkPackage).not.toHaveBeenCalled();
    expect(reorderWorkPackages).not.toHaveBeenCalled();
  });
});
