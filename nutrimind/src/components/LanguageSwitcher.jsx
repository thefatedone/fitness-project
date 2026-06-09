"use client";
import { useTranslation } from "react-i18next";

export default function LanguageSwitcher() {
  const { i18n } = useTranslation();

  const currentLang = i18n.language || "en";

  const languages = [
    { code: "en", label: "EN" },
    { code: "ka", label: "ქარ" },
  ];

  const handleChange = (code) => {
    i18n.changeLanguage(code);
    document.documentElement.lang = code;
  };

  return (
    <div className="flex items-center gap-1 px-2 py-1.5 rounded-xl bg-[#1a1a1a]">
      {languages.map((lang) => {
        const isActive = currentLang === lang.code;
        return (
          <button
            key={lang.code}
            onClick={() => handleChange(lang.code)}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 ${
              isActive
                ? "bg-[#22c55e] text-black"
                : "text-white/70 hover:text-white hover:bg-white/10"
            }`}
          >
            {lang.label}
          </button>
        );
      })}
    </div>
  );
}
