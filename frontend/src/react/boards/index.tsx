import React from 'react';
import type { Root } from 'react-dom/client';
import { BoardApp } from './BoardApp';
import type { BoardPermissions } from './context/BoardContext';
import { boardRootFactory } from './root-factory';

let root:Root | null = null;
let mountedContainer:HTMLElement | null = null;

export function mountBoardRoot(doc:Document = document) {
  const container = doc.getElementById('react-board-root');
  if (!container) {
    return;
  }

  if (root && mountedContainer === container) {
    return;
  }

  const boardId = Number(container.dataset.boardId);
  const projectId = container.dataset.projectId ?? '';
  const permissions:BoardPermissions = {
    canManage: container.dataset.canManage === 'true',
  };

  unmountBoardRoot();

  mountedContainer = container;
  root = boardRootFactory.create(container);
  root.render(
    <BoardApp
      boardId={boardId}
      projectId={projectId}
      permissions={permissions}
    />,
  );
}

export function unmountBoardRoot() {
  if (root) {
    root.unmount();
    root = null;
  }

  mountedContainer = null;
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => mountBoardRoot());
} else {
  mountBoardRoot();
}

document.addEventListener('turbo:load', () => mountBoardRoot());
document.addEventListener('turbo:before-render', () => unmountBoardRoot());
