import React, { useEffect, useRef, useState } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { PrimerProviderWrapper } from 'core-react/bridge/primer-provider-wrapper';
import { BoardProvider } from './context/BoardContext';
import { useBoardQuery } from './hooks/useBoardQuery';
import { BoardToolbar } from './components/BoardToolbar';
import { BoardCanvas } from './components/BoardCanvas';
import type { BoardPermissions } from './context/BoardContext';
import type { ApiV3Filter } from './api/types';
import { initialBoardFilters } from './state/initial-board-filters';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: true,
      retry: 1,
    },
  },
});

interface BoardAppInnerProps {
  boardId:number;
  projectId:string;
  permissions:BoardPermissions;
}

function BoardAppInner({ boardId, projectId, permissions }:BoardAppInnerProps) {
  const { data: board, isLoading, error } = useBoardQuery(boardId);
  const [filters, setFilters] = useState<ApiV3Filter[]>([]);
  const seededBoardId = useRef<number | null>(null);

  useEffect(() => {
    if (!board || seededBoardId.current === board.id) {
      return;
    }

    seededBoardId.current = board.id;
    setFilters(initialBoardFilters(board.options.filters ?? []));
  }, [board]);

  if (isLoading) {
    return <div className="op-board-loading">Loading board...</div>;
  }

  if (error || !board) {
    return <div className="op-board-error">Failed to load board.</div>;
  }

  const isActionBoard = board.options.type === 'action';
  const actionAttribute = board.options.attribute;

  return (
    <BoardProvider
      value={{
        boardId,
        projectId,
        board,
        permissions,
        isActionBoard,
        actionAttribute,
      }}
    >
      <div className="op-board">
        <BoardToolbar
          boardName={board.name}
          filters={filters}
          onFiltersChange={setFilters}
        />
        <BoardCanvas board={board} filters={filters} />
      </div>
    </BoardProvider>
  );
}

interface BoardAppProps {
  boardId:number;
  projectId:string;
  permissions:BoardPermissions;
}

export function BoardApp({ boardId, projectId, permissions }:BoardAppProps) {
  return (
    <QueryClientProvider client={queryClient}>
      <PrimerProviderWrapper>
        <BoardAppInner
          boardId={boardId}
          projectId={projectId}
          permissions={permissions}
        />
      </PrimerProviderWrapper>
    </QueryClientProvider>
  );
}
