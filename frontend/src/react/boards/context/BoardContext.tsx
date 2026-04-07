import React, { createContext, useContext } from 'react';
import type { BoardGrid } from '../api/types';

export interface BoardPermissions {
  canManage:boolean;
}

export interface BoardContextValue {
  boardId:number;
  projectId:string;
  board:BoardGrid;
  permissions:BoardPermissions;
  isActionBoard:boolean;
  actionAttribute:string | undefined;
}

const BoardContext = createContext<BoardContextValue | null>(null);

export function BoardProvider({
  children,
  value,
}:{
  children:React.ReactNode;
  value:BoardContextValue;
}) {
  return (
    <BoardContext.Provider value={value}>{children}</BoardContext.Provider>
  );
}

export function useBoardContext():BoardContextValue {
  const ctx = useContext(BoardContext);
  if (!ctx) {
    throw new Error('useBoardContext must be used within BoardProvider');
  }
  return ctx;
}
