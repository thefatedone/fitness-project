"use client";
import { useTranslation } from "react-i18next";
import { Languages } from "lucide-react";

const LANGUAGES = [
  { code: "en", label: "EN", nativeName: "English" },
  { code: "ka", label: "ქარ", nativeName: "ქართული" },
  { code: "ru", label: "RU", nativeName: "Русский" },
];

export default function LanguageSwitcher() {
  const { i18n } = useTranslation();
  const currentLang = i18n.language || "en";

  const handleChange = (code) => {
    if (code === currentLang) return;
    i18n.changeLanguage(code);
    if (typeof document !== "undefined") {
      document.documentElement.lang = code;
    }
  };

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center gap-2 px-1 text-[10px] uppercase tracking-widest font-semibold text-gray-500">
        <Languages className="w-3.5 h-3.5" aria-hidden="true" />
        <span>Language</span>
      </div>
      <div
        role="radiogroup"
        aria-label="Language"
        className="grid grid-cols-3 gap-1 p-1 rounded-xl bg-[#16181d] border border-white/5"
      >
        {LANGUAGES.map((lang) => {
          const isActive = currentLang === lang.code;
          return (
            <button
              key={lang.code}
              type="button"
              role="radio"
              aria-checked={isActive}
              aria-label={lang.nativeName}
              onClick={() => handleChange(lang.code)}
              className={`px-2 py-1.5 rounded-lg text-xs font-semibold transition-all duration-200 ${
                isActive
                  ? "bg-[#22c55e] text-black shadow-sm shadow-[#22c55e]/30"
                  : "text-white/60 hover:text-white hover:bg-white/5"
              }`}
            >
              {lang.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
