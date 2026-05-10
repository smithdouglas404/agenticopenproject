/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-return */

import {
  draggable,
  dropTargetForElements,
} from '@atlaskit/pragmatic-drag-and-drop/element/adapter';

import ItemController from './item.controller';

vi.mock('@atlaskit/pragmatic-drag-and-drop/combine', () => ({
  combine: vi.fn(() => vi.fn()),
}));

vi.mock('@atlaskit/pragmatic-drag-and-drop/element/adapter', () => ({
  draggable: vi.fn(() => vi.fn()),
  dropTargetForElements: vi.fn(() => vi.fn()),
}));

describe('WorkPackageCardBox item controller', () => {
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

  function connectedControllerFor(element:HTMLElement, itemId = '123') {
    const controller = Object.create(ItemController.prototype) as ItemController;

    Object.defineProperty(controller, 'element', { value: element });
    Object.defineProperty(controller, 'itemIdValue', { value: itemId });
    Object.defineProperty(controller, 'sourceIdValue', { value: 'inbox' });
    Object.defineProperty(controller, 'dragTypeValue', { value: 'backlogs-item' });

    controller.connect();

    return controller;
  }

  function itemRow(id:string, selected = false):HTMLLIElement {
    const row = document.createElement('li');
    const item = document.createElement('article');

    item.setAttribute('data-work-package-card-box-target', 'item');
    item.setAttribute('data-work-package-card-box-item-id', id);
    item.setAttribute('data-work-package-card-box--item-item-id-value', id);
    item.setAttribute('data-work-package-card-box--item-source-id-value', 'inbox');
    item.setAttribute('data-work-package-card-box--item-drag-type-value', 'backlogs-item');

    if (selected) {
      item.setAttribute('data-work-package-card-box-selected', 'true');
    }

    row.appendChild(item);

    return row;
  }

  beforeEach(() => {
    vi.clearAllMocks();
  });

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

  it('uses the selected item ids in DOM order when dragging a selected item', () => {
    const list = document.createElement('ul');
    const first = itemRow('1', true);
    const second = itemRow('2', true);
    const third = itemRow('3', false);
    const draggedItem = second.querySelector<HTMLElement>('article')!;

    list.append(first, second, third);
    document.body.appendChild(list);

    connectedControllerFor(draggedItem, '2');

    const data = vi.mocked(draggable).mock.lastCall?.[0].getInitialData?.({
      element: draggedItem,
      dragHandle: null,
      input: {} as never,
    });

    expect(data).toMatchObject({
      type: 'work-package-card-box-item',
      dragType: 'backlogs-item',
      itemId: '2',
      itemIds: ['1', '2'],
      sourceId: 'inbox',
    });
  });

  it('uses only the dragged item id when dragging an unselected item', () => {
    const list = document.createElement('ul');
    const first = itemRow('1', true);
    const second = itemRow('2', true);
    const draggedItem = itemRow('3', false).querySelector<HTMLElement>('article')!;

    list.append(first, second, draggedItem.closest('li')!);
    document.body.appendChild(list);

    connectedControllerFor(draggedItem, '3');

    const data = vi.mocked(draggable).mock.lastCall?.[0].getInitialData?.({
      element: draggedItem,
      dragHandle: null,
      input: {} as never,
    });

    expect(data).toMatchObject({
      itemId: '3',
      itemIds: ['3'],
    });
  });
});
