import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";

import enTranslation from "@/i18n/locales/en/translation.json";
import kaTranslation from "@/i18n/locales/ka/translation.json";

const resources = {
  en: { translation: enTranslation },
  ka: { translation: kaTranslation },
};

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: "en",
    defaultNS: "translation",
    ns: ["translation"],
    interpolation: {
      escapeValue: false,
    },
    detection: {
      order: ["localStorage", "navigator"],
      caches: ["localStorage"],
      lookupLocalStorage: "nutrimind_lang",
    },
  });

// Sync document.documentElement.lang with i18next language
i18n.on("languageChanged", (lng) => {
  document.documentElement.lang = lng;
});

// Set initial lang attribute on page load (guard for SSR)
if (typeof document !== "undefined") {
  document.documentElement.lang = i18n.language || "en";
}

export default i18n;
