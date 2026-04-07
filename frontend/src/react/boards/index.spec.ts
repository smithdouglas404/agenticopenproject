import { mountBoardRoot, unmountBoardRoot } from './index';
import { boardRootFactory } from './root-factory';

describe('react boards entrypoint', () => {
  let mockRoot:{
    render:jasmine.Spy;
    unmount:jasmine.Spy;
  };
  let createRootSpy:jasmine.Spy;

  beforeEach(() => {
    mockRoot = {
      render: jasmine.createSpy('render'),
      unmount: jasmine.createSpy('unmount'),
    };

    document.body.innerHTML = `
      <div
        id="react-board-root"
        data-board-id="42"
        data-project-id="demo-project"
        data-can-manage="true"
      ></div>
    `;

    mockRoot.render.calls.reset();
    mockRoot.unmount.calls.reset();
    createRootSpy = spyOn(boardRootFactory, 'create').and.returnValue(mockRoot as never);
  });

  afterEach(() => {
    unmountBoardRoot();
    document.body.innerHTML = '';
  });

  it('mounts once for the initial container', () => {
    mountBoardRoot();

    expect(createRootSpy.calls.count()).toBe(1);
    expect(mockRoot.render.calls.count()).toBe(1);
  });

  it('does not create a second root for the same container', () => {
    mountBoardRoot();
    mountBoardRoot();

    expect(createRootSpy.calls.count()).toBe(1);
    expect(mockRoot.render.calls.count()).toBe(1);
  });

  it('unmounts the current root', () => {
    mountBoardRoot();

    unmountBoardRoot();

    expect(mockRoot.unmount.calls.count()).toBe(1);
  });
});
