"use client";
import { createContext, useContext, useState, useEffect, ReactNode } from "react";

export type Locale = "en" | "ka" | "ru";

interface LanguageContextType {
  locale: Locale;
  setLocale: (locale: Locale) => void;
}

const LanguageContext = createContext<LanguageContextType>({
  locale: "en",
  setLocale: () => {},
});

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("en");

  useEffect(() => {
    const saved = localStorage.getItem("nutrimind_locale") as Locale;
    if (saved === "en" || saved === "ka" || saved === "ru") {
      setLocaleState(saved);
    }
  }, []);

  // Keep <html lang="..."> in sync with the selected locale. This was
  // previously never updated on the landing page (only the separate
  // dashboard i18next setup did this), so language-aware CSS selectors
  // like `html[lang="ka"] body { ... }` never actually matched here.
  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  const setLocale = (newLocale: Locale) => {
    setLocaleState(newLocale);
    localStorage.setItem("nutrimind_locale", newLocale);
  };

  return (
    <LanguageContext.Provider value={{ locale, setLocale }}>
      {children}
    </LanguageContext.Provider>
  );
}

export const useLanguage = () => useContext(LanguageContext);
