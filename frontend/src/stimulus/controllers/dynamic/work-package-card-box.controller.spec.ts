import { Application } from '@hotwired/stimulus';

import WorkPackageCardBoxController from './work-package-card-box.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));
const settleStimulus = async () => {
  await nextFrame();
  await nextFrame();
};

describe('WorkPackageCardBoxController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  beforeEach(async () => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);

    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('work-package-card-box', WorkPackageCardBoxController);
    await nextFrame();
  });

  afterEach(() => {
    Stimulus.stop();
    fixturesElement.remove();
  });

  function appendBox({
    id,
    sourceId,
    itemIds,
  }:{
    id:string;
    sourceId:string;
    itemIds:string[];
  }) {
    fixturesElement.insertAdjacentHTML('beforeend', `
      <section
        id="${id}"
        data-controller="work-package-card-box"
        data-work-package-card-box-source-id-value="${sourceId}"
        data-work-package-card-box-selection-group-value="backlogs"
        data-work-package-card-box-selected-class="Box-card--multi-selected"
      >
        ${itemIds.map((itemId) => `
          <article
            id="${id}-${itemId}"
            class="Box-card"
            data-work-package-card-box-target="item"
            data-work-package-card-box-item-id="${itemId}"
            data-action="click->work-package-card-box#toggleSelection"
          >${itemId}</article>
        `).join('')}
      </section>
    `);
  }

  function clickItem(id:string, options:MouseEventInit = {}) {
    document.getElementById(id)!.dispatchEvent(new MouseEvent('click', {
      bubbles: true,
      cancelable: true,
      ...options,
    }));
  }

  function selectedIds(boxId:string) {
    return Array
      .from(document.querySelectorAll<HTMLElement>(`#${boxId} [data-work-package-card-box-selected="true"]`))
      .map((element) => element.dataset.workPackageCardBoxItemId);
  }

  it('toggles an item with a meta click and marks it as selected', async () => {
    appendBox({ id: 'box-a', sourceId: 'inbox', itemIds: ['1', '2', '3'] });
    await settleStimulus();

    expect(Stimulus.getControllerForElementAndIdentifier(
      document.getElementById('box-a')!,
      'work-package-card-box',
    )).toBeDefined();

    clickItem('box-a-2', { metaKey: true });
    await nextFrame();

    const item = document.getElementById('box-a-2')!;

    expect(selectedIds('box-a')).toEqual(['2']);
    expect(item.classList).toContain('Box-card--multi-selected');
    expect(item.getAttribute('aria-selected')).toEqual('true');

    clickItem('box-a-2', { metaKey: true });
    await nextFrame();

    expect(selectedIds('box-a')).toEqual([]);
    expect(item.classList).not.toContain('Box-card--multi-selected');
    expect(item.hasAttribute('aria-selected')).toBe(false);
  });

  it('deselects a selected item with a plain click', async () => {
    appendBox({ id: 'box-a', sourceId: 'inbox', itemIds: ['1', '2', '3'] });
    await settleStimulus();

    clickItem('box-a-2', { metaKey: true });
    await nextFrame();

    clickItem('box-a-2');
    await nextFrame();

    expect(selectedIds('box-a')).toEqual([]);
  });

  it('range selects from the last selected item with a shift click', async () => {
    appendBox({ id: 'box-a', sourceId: 'inbox', itemIds: ['1', '2', '3', '4'] });
    await settleStimulus();

    clickItem('box-a-1', { metaKey: true });
    clickItem('box-a-4', { shiftKey: true });
    await nextFrame();

    expect(selectedIds('box-a')).toEqual(['1', '2', '3', '4']);
  });

  it('clears a peer card box in the same selection group', async () => {
    appendBox({ id: 'box-a', sourceId: 'inbox', itemIds: ['1', '2'] });
    appendBox({ id: 'box-b', sourceId: 'sprint:5', itemIds: ['3', '4'] });
    await settleStimulus();

    clickItem('box-a-1', { metaKey: true });
    clickItem('box-b-3', { metaKey: true });
    await nextFrame();

    expect(selectedIds('box-a')).toEqual([]);
    expect(selectedIds('box-b')).toEqual(['3']);
  });

  it('ignores plain clicks so card click navigation can handle them', async () => {
    appendBox({ id: 'box-a', sourceId: 'inbox', itemIds: ['1'] });
    await settleStimulus();

    clickItem('box-a-1');
    await nextFrame();

    expect(selectedIds('box-a')).toEqual([]);
  });
});
