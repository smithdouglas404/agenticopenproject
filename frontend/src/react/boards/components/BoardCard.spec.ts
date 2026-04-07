import React from 'react';
import { createRoot } from 'react-dom/client';
import { flushSync } from 'react-dom';
import { BoardCard } from './BoardCard';
import type { WorkPackage } from '../api/types';

describe('BoardCard', () => {
  let container:HTMLDivElement;
  let root:ReturnType<typeof createRoot>;

  const workPackage = {
    id: 33,
    subject: 'Implement user authentication',
    lockVersion: 7,
    _links: {
      self: { href: '/api/v3/work_packages/33' },
      type: { href: '/api/v3/types/1', title: 'Feature' },
      status: { href: '/api/v3/statuses/1', title: 'In specification' },
      priority: { href: '/api/v3/priorities/1', title: 'Medium' },
      assignee: { href: '/api/v3/users/5', title: 'Jay Pisine' },
      project: { href: '/api/v3/projects/1', title: 'Demo' },
    },
  } as WorkPackage;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(() => {
    root.unmount();
    container.remove();
  });

  it('renders the updated visual shell for board cards', () => {
    flushSync(() => {
      root.render(
        React.createElement(BoardCard, {
          workPackage,
          queryId: '476',
          index: 0,
          order: ['33'],
          positions: { '33': 0 },
          isDragDisabled: true,
        }),
      );
    });

    const card = container.querySelector<HTMLDivElement>('[data-test-selector="op-wp-single-card"]');
    const handle = container.querySelector('[data-test-selector="op-board-card--drag-handle"]');
    const typeBadge = container.querySelector('[data-test-selector="op-board-card--type"]');
    const footer = container.querySelector('[data-test-selector="op-board-card--footer"]');
    const priority = container.querySelector('[data-test-selector="op-board-card--content-priority"]');

    expect(card).not.toBeNull();
    expect(card?.style.boxShadow).toContain('rgba(0, 0, 0, 0.04)');
    expect(handle).not.toBeNull();
    expect(typeBadge?.textContent).toBe('FEATURE');
    expect(typeBadge?.classList.contains('__hl_inline_type_1')).toBe(true);
    expect(footer).not.toBeNull();
    expect(priority?.textContent).toContain('Medium');
  });

  it('does not duplicate status into the assignee slot when assignee is missing', () => {
    const workPackageWithoutAssignee = {
      ...workPackage,
      _links: {
        ...workPackage._links,
        assignee: undefined,
      },
    } as WorkPackage;

    flushSync(() => {
      root.render(
        React.createElement(BoardCard, {
          workPackage: workPackageWithoutAssignee,
          queryId: '476',
          index: 0,
          order: ['33'],
          positions: { '33': 0 },
          isDragDisabled: true,
        }),
      );
    });

    const assignee = container.querySelector('[data-test-selector="op-wp-single-card--content-assignee"]');
    const status = container.querySelector('[data-test-selector="op-wp-single-card--content-status"]');

    expect(assignee).toBeNull();
    expect(status?.textContent?.trim()).toBe('In specification');
    expect(container.textContent?.includes('In specificationIn specification')).toBe(false);
  });
});
