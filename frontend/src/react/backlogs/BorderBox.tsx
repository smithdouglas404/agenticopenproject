import { ReactNode } from 'react';

interface WrapperProps {
  mainColumn?:boolean;
  children:ReactNode;
}

interface BorderBoxRowProps {
   children:ReactNode; 
}

interface BorderBoxHeadingProps {
   children:ReactNode; 
}

export function BorderBoxRow({ children }:BorderBoxRowProps) {
  return (
    <div className={'op-border-box-grid'}>{children}</div>
  );
}

export function BorderBoxHeading({ children }:BorderBoxHeadingProps) {
  return (
    <span className={'op-border-box-grid--heading text-semibold'}>{children}</span>
  );
}

export function BorderBoxColumn({ mainColumn, children }:WrapperProps) {
  return (
    <div className={`op-border-box-grid--row-item ${mainColumn ? 'op-border-box-grid--main-column' : ''}`}>{children}</div>
  );
}
