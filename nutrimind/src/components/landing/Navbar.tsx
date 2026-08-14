"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Menu, X, Globe, Sun, Moon } from "lucide-react";
import { useLanguage } from "@/context/LanguageContext";
import { useTheme } from "@/context/ThemeContext";
import { useTranslations } from "@/hooks/useTranslations";
import Button from "@/components/ui/Button";

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const { locale, setLocale } = useLanguage();
  const { theme, toggleTheme } = useTheme();
  const { t } = useTranslations("navbar");

  const toggleLocale = () => {
    setLocale(locale === "en" ? "ka" : "en");
  };

  const navLinks = [
    { href: "#features", label: t("features") },
    { href: "#pricing", label: t("pricing") },
  ];

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b backdrop-blur-xl bg-[var(--nav)] border-[var(--border)]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <a href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#22c55e] flex items-center justify-center">
              <span className="text-black font-bold text-lg">N</span>
            </div>
            <span className="ln-text font-semibold text-lg">NutriMind</span>
          </a>

          <div className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <a key={link.href} href={link.href} className="ln-link">
                {link.label}
              </a>
            ))}

            <button onClick={toggleTheme} className="theme-toggle-btn" aria-label="Toggle theme">
              <AnimatePresence mode="wait">
                {theme === "dark" ? (
                  <motion.div
                    key="sun"
                    initial={{ scale: 0, rotate: -180, opacity: 0 }}
                    animate={{ scale: 1, rotate: 0, opacity: 1 }}
                    exit={{ scale: 0, rotate: 180, opacity: 0 }}
                    transition={{ duration: 0.35, ease: [0.34, 1.56, 0.64, 1] }}
                  >
                    <Sun className="w-4 h-4" style={{ color: "#fbbf24" }} />
                  </motion.div>
                ) : (
                  <motion.div
                    key="moon"
                    initial={{ scale: 0, rotate: 180, opacity: 0 }}
                    animate={{ scale: 1, rotate: 0, opacity: 1 }}
                    exit={{ scale: 0, rotate: -180, opacity: 0 }}
                    transition={{ duration: 0.35, ease: [0.34, 1.56, 0.64, 1] }}
                  >
                    <Moon className="w-4 h-4" style={{ color: "#6366f1" }} />
                  </motion.div>
                )}
              </AnimatePresence>
            </button>

            <button
              onClick={toggleLocale}
              className="ln-link flex items-center gap-1.5 px-2 py-1 rounded-lg hover:bg-[var(--border)]/50"
              aria-label="Toggle language"
            >
              <Globe className="w-4 h-4" />
              <span className="text-sm font-medium uppercase">{locale}</span>
            </button>

            <a href="/login" className="ln-link">
              {t("signIn")}
            </a>
            <Button href="/register" variant="primary" className="!px-4 !py-2 text-sm">
              {t("startFree")}
            </Button>
          </div>

          <button
            className="md:hidden p-2 ln-text"
            onClick={() => setIsOpen(!isOpen)}
            aria-label="Toggle menu"
          >
            {isOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </div>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            transition={{ duration: 0.3, ease: [0.32, 0.72, 0, 1] }}
            className="md:hidden absolute top-16 left-0 right-0"
          >
            <div className="flex flex-col p-6 gap-4 border-b backdrop-blur-xl bg-[var(--nav)] border-[var(--border)]">
              {navLinks.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  className="ln-link py-2"
                  onClick={() => setIsOpen(false)}
                >
                  {link.label}
                </a>
              ))}

              <button
                onClick={() => {
                  toggleTheme();
                  setIsOpen(false);
                }}
                className="ln-link flex items-center gap-3 py-2"
              >
                <AnimatePresence mode="wait">
                  {theme === "dark" ? (
                    <motion.div
                      key="sun-m"
                      initial={{ rotate: -90, opacity: 0 }}
                      animate={{ rotate: 0, opacity: 1 }}
                      exit={{ rotate: 90, opacity: 0 }}
                      transition={{ duration: 0.3 }}
                    >
                      <Sun className="w-4 h-4" style={{ color: "#fbbf24" }} />
                    </motion.div>
                  ) : (
                    <motion.div
                      key="moon-m"
                      initial={{ rotate: 90, opacity: 0 }}
                      animate={{ rotate: 0, opacity: 1 }}
                      exit={{ rotate: -90, opacity: 0 }}
                      transition={{ duration: 0.3 }}
                    >
                      <Moon className="w-4 h-4" style={{ color: "#6366f1" }} />
                    </motion.div>
                  )}
                </AnimatePresence>
                <span className="text-sm font-medium">
                  {theme === "dark" ? "Light Mode" : "Dark Mode"}
                </span>
              </button>

              <button
                onClick={() => {
                  toggleLocale();
                  setIsOpen(false);
                }}
                className="ln-link flex items-center gap-3 py-2"
              >
                <Globe className="w-4 h-4" />
                <span className="text-sm font-medium uppercase">
                  {locale === "en" ? "Georgian (KA)" : "English (EN)"}
                </span>
              </button>

              <a
                href="/login"
                className="ln-link py-2"
                onClick={() => setIsOpen(false)}
              >
                {t("signIn")}
              </a>
              <Button
                href="/register"
                variant="primary"
                className="mt-2 !py-3 text-center"
                onClick={() => setIsOpen(false)}
              >
                {t("startFree")}
              </Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}
