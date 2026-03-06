import React, { type ReactNode } from 'react';
import { BaseStyles, ThemeProvider } from '@primer/react';
import { useOpTheme } from '../hooks/useOpTheme';

interface PrimerProviderWrapperProps {
  children:ReactNode;
}

export function PrimerProviderWrapper({ children }:PrimerProviderWrapperProps) {
  const theme = useOpTheme();
  const colorMode = theme === 'dark' ? 'night' : 'day';

  return (
    <ThemeProvider colorMode={colorMode}>
      <BaseStyles>
        {children}
      </BaseStyles>
    </ThemeProvider>
  );
}
