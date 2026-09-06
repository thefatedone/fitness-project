"use client";
import { motion } from "framer-motion";
import { Globe } from "lucide-react";
import { useLanguage, type Locale } from "@/context/LanguageContext";

const LANGUAGES: { code: Locale; label: string }[] = [
  { code: "en", label: "EN" },
  { code: "ka", label: "KA" },
  { code: "ru", label: "RU" },
];

export default function LanguagePicker() {
  const { locale, setLocale } = useLanguage();

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.55, ease: [0.16, 1, 0.3, 1], delay: 0.4 }}
      role="group"
      aria-label="Language"
      className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-1 rounded-full px-2 py-2 backdrop-blur-xl bg-[var(--background)]/90 dark:bg-[var(--card)]/90 border border-[var(--border)]/40 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.45),0_8px_16px_-8px_rgba(0,0,0,0.2)]"
    >
      <Globe className="w-4 h-4 mx-2 text-[var(--foreground-muted)]" aria-hidden="true" />
      {LANGUAGES.map((lang) => {
        const isActive = locale === lang.code;
        return (
          <button
            key={lang.code}
            onClick={() => setLocale(lang.code)}
            aria-pressed={isActive}
            aria-label={`Switch language to ${lang.label}`}
            className="px-4 py-1.5 rounded-full text-sm font-semibold transition-colors"
            style={
              isActive
                ? { backgroundColor: "#22c55e", color: "#000" }
                : { color: "var(--foreground-muted)" }
            }
          >
            {lang.label}
          </button>
        );
      })}
    </motion.div>
  );
}
