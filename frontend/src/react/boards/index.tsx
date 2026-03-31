import React from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { BoardApp } from './BoardApp';
import type { BoardPermissions } from './context/BoardContext';

let root: Root | null = null;

function mount() {
  const container = document.getElementById('react-board-root');
  if (!container) return;

  const boardId = Number(container.dataset.boardId);
  const projectId = container.dataset.projectId ?? '';
  const permissions: BoardPermissions = {
    canManage: container.dataset.canManage === 'true',
  };

  root = createRoot(container);
  root.render(
    <BoardApp
      boardId={boardId}
      projectId={projectId}
      permissions={permissions}
    />,
  );
}

function unmount() {
  if (root) {
    root.unmount();
    root = null;
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mount);
} else {
  mount();
}

document.addEventListener('turbo:load', mount);
document.addEventListener('turbo:before-render', unmount);
