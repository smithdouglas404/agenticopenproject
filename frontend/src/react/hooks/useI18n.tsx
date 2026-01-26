

import React, { createContext, useState, useEffect, useContext } from 'react';


const I18nContext = createContext<I18nContextValue|undefined>(undefined);

export interface I18nContextValue {
  locale:string;
  setLocale:(locale:string) => void;
  t:(key:string, options?:Record<string, unknown>) => string;
}

export function I18nProvider({ children }:{ children:React.ReactNode }) {
  const [locale, setLocale] = useState(window.I18n.locale);

  useEffect(() => {
    I18n.locale = locale;
  }, [locale]);

  return (
    <I18nContext.Provider value={{ locale, setLocale, t: I18n.t.bind(I18n) }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  const context = useContext(I18nContext);

  if (!context) {
    throw new Error('useI18n must be used within an I18nProvider');
  }

  return context;
}
