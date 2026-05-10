/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-return */

import { dropTargetForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';

import ItemController from './item.controller';

vi.mock('@atlaskit/pragmatic-drag-and-drop/combine', () => ({
  combine: vi.fn(() => vi.fn()),
}));

vi.mock('@atlaskit/pragmatic-drag-and-drop/element/adapter', () => ({
  draggable: vi.fn(() => vi.fn()),
  dropTargetForElements: vi.fn(() => vi.fn()),
}));

describe('Backlogs item controller', () => {
  type TestItemState =
    | { type:'idle' }
    | { type:'is-dragging-over'; closestEdge:'top' | 'bottom' | null };

  interface TestItemController {
    state:TestItemState;
    setState(state:TestItemState):void;
  }

  function controllerFor(element:HTMLElement) {
    const controller = Object.create(ItemController.prototype) as unknown as TestItemController;

    Object.defineProperty(controller, 'element', { value: element });
    controller.state = { type: 'idle' };

    return controller;
  }

  function connectedControllerFor(element:HTMLElement) {
    const controller = Object.create(ItemController.prototype) as ItemController;

    Object.defineProperty(controller, 'element', { value: element });
    Object.defineProperty(controller, 'itemIdValue', { value: '123' });

    controller.connect();

    return controller;
  }

  it('marks the closest edge while dragging over an item', () => {
    const element = document.createElement('article');
    const controller = controllerFor(element);

    controller.setState({ type: 'is-dragging-over', closestEdge: 'top' });

    expect(element.dataset.dropPosition).toEqual('top');
  });

  it('removes the drop position when leaving an item', () => {
    const element = document.createElement('article');
    const controller = controllerFor(element);

    controller.setState({ type: 'is-dragging-over', closestEdge: 'bottom' });
    controller.setState({ type: 'idle' });

    expect(element.hasAttribute('data-drop-position')).toBe(false);
  });

  it('keeps the item drop target active while dragging across item gaps', () => {
    const element = document.createElement('article');

    connectedControllerFor(element);

    expect(vi.mocked(dropTargetForElements).mock.lastCall?.[0].getIsSticky?.({
      element,
      input: {} as never,
      source: {
        data: {},
        element: document.createElement('article'),
      } as never,
    })).toBe(true);
  });
});
