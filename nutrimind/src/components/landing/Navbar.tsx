"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Menu, X, Globe, Sun, Moon } from "lucide-react";
import { useLanguage } from "@/context/LanguageContext";
import { useTheme } from "@/context/ThemeContext";

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const { locale, setLocale } = useLanguage();
  const { theme, toggleTheme } = useTheme();

  const toggleLocale = () => {
    setLocale(locale === "en" ? "ka" : "en");
  };

  return (
    <nav
      className="fixed top-0 left-0 right-0 z-50 transition-all duration-500 ease-in-out"
      style={{
        backgroundColor: theme === 'dark' ? 'rgba(10, 10, 10, 0.95)' : 'rgba(255, 255, 255, 0.95)',
        backdropFilter: 'blur(20px)',
        borderBottomWidth: '1px',
        borderBottomStyle: 'solid',
        borderBottomColor: theme === 'dark' ? '#1a1a1a' : '#e5e7eb',
      }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <a href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#22c55e] flex items-center justify-center">
              <span className="text-black font-bold text-lg">N</span>
            </div>
            <span
              className="font-semibold text-lg transition-all duration-500 ease-in-out"
              style={{ color: theme === 'dark' ? '#ededed' : '#111827' }}
            >
              NutriMind
            </span>
          </a>

          <div className="hidden md:flex items-center gap-8">
            <a
              href="#features"
              className="transition-colors duration-500 ease-in-out"
              style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
              onMouseEnter={e => e.currentTarget.style.color = theme === 'dark' ? '#ededed' : '#111827'}
              onMouseLeave={e => e.currentTarget.style.color = theme === 'dark' ? '#6b6b6b' : '#4b5563'}
            >
              Features
            </a>
            <a
              href="#pricing"
              className="transition-colors duration-500 ease-in-out"
              style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
              onMouseEnter={e => e.currentTarget.style.color = theme === 'dark' ? '#ededed' : '#111827'}
              onMouseLeave={e => e.currentTarget.style.color = theme === 'dark' ? '#6b6b6b' : '#4b5563'}
            >
              Pricing
            </a>

            <button
              onClick={toggleTheme}
              className="theme-toggle-btn"
              aria-label="Toggle theme"
            >
              <AnimatePresence mode="wait">
                {theme === "dark" ? (
                  <motion.div
                    key="sun"
                    initial={{ scale: 0, rotate: -180, opacity: 0 }}
                    animate={{ scale: 1, rotate: 0, opacity: 1 }}
                    exit={{ scale: 0, rotate: 180, opacity: 0 }}
                    transition={{ duration: 0.35, ease: [0.34, 1.56, 0.64, 1] }}
                  >
                    <Sun className="w-4 h-4" style={{ color: '#fbbf24' }} />
                  </motion.div>
                ) : (
                  <motion.div
                    key="moon"
                    initial={{ scale: 0, rotate: 180, opacity: 0 }}
                    animate={{ scale: 1, rotate: 0, opacity: 1 }}
                    exit={{ scale: 0, rotate: -180, opacity: 0 }}
                    transition={{ duration: 0.35, ease: [0.34, 1.56, 0.64, 1] }}
                  >
                    <Moon className="w-4 h-4" style={{ color: '#6366f1' }} />
                  </motion.div>
                )}
              </AnimatePresence>
            </button>

            <button
              onClick={toggleLocale}
              className="flex items-center gap-1.5 px-2 py-1 rounded-lg transition-all duration-500 ease-in-out"
              style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
              onMouseEnter={e => e.currentTarget.style.backgroundColor = theme === 'dark' ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)'}
              onMouseLeave={e => e.currentTarget.style.backgroundColor = 'transparent'}
              aria-label="Toggle language"
            >
              <Globe className="w-4 h-4" />
              <span className="text-sm font-medium uppercase">{locale}</span>
            </button>

            <a
              href="/login"
              className="transition-colors duration-500 ease-in-out"
              style={{ color: theme === 'dark' ? '#6b6b6b' : '#374151' }}
              onMouseEnter={e => e.currentTarget.style.color = theme === 'dark' ? '#ededed' : '#111827'}
              onMouseLeave={e => e.currentTarget.style.color = theme === 'dark' ? '#6b6b6b' : '#374151'}
            >
              Sign In
            </a>
            <a
              href="/register"
              className="px-4 py-2 rounded-full bg-[#22c55e] text-black font-medium hover:bg-[#16a34a] active:scale-[0.98] transition-all duration-300"
            >
              Start Free
            </a>
          </div>

          <button
            className="md:hidden p-2 transition-all duration-500 ease-in-out"
            style={{ color: theme === 'dark' ? '#ededed' : '#111827' }}
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
            <div
              className="flex flex-col p-6 gap-4 border-b transition-all duration-500 ease-in-out"
              style={{
                backgroundColor: theme === 'dark' ? 'rgba(10, 10, 10, 0.98)' : 'rgba(255, 255, 255, 0.98)',
                backdropFilter: 'blur(20px)',
                borderBottomWidth: '1px',
                borderBottomStyle: 'solid',
                borderBottomColor: theme === 'dark' ? '#1a1a1a' : '#e5e7eb',
              }}
            >
              <a
                href="#features"
                className="py-2 transition-colors duration-500 ease-in-out"
                style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
                onClick={() => setIsOpen(false)}
              >
                Features
              </a>
              <a
                href="#pricing"
                className="py-2 transition-colors duration-500 ease-in-out"
                style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
                onClick={() => setIsOpen(false)}
              >
                Pricing
              </a>

              <button
                onClick={() => { toggleTheme(); setIsOpen(false); }}
                className="flex items-center gap-3 py-2 transition-all duration-500 ease-in-out"
                style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
              >
                <AnimatePresence mode="wait">
                  {theme === "dark" ? (
                    <motion.div key="sun-m" initial={{ rotate: -90, opacity: 0 }} animate={{ rotate: 0, opacity: 1 }} exit={{ rotate: 90, opacity: 0 }} transition={{ duration: 0.3 }}>
                      <Sun className="w-4 h-4" style={{ color: '#fbbf24' }} />
                    </motion.div>
                  ) : (
                    <motion.div key="moon-m" initial={{ rotate: 90, opacity: 0 }} animate={{ rotate: 0, opacity: 1 }} exit={{ rotate: -90, opacity: 0 }} transition={{ duration: 0.3 }}>
                      <Moon className="w-4 h-4" style={{ color: '#6366f1' }} />
                    </motion.div>
                  )}
                </AnimatePresence>
                <span className="text-sm font-medium">{theme === "dark" ? "Light Mode" : "Dark Mode"}</span>
              </button>

              <button
                onClick={() => { toggleLocale(); setIsOpen(false); }}
                className="flex items-center gap-3 py-2 transition-all duration-500 ease-in-out"
                style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
              >
                <Globe className="w-4 h-4" />
                <span className="text-sm font-medium uppercase">{locale === "en" ? "Georgian (KA)" : "English (EN)"}</span>
              </button>

              <a
                href="/login"
                className="py-2 transition-colors duration-500 ease-in-out"
                style={{ color: theme === 'dark' ? '#6b6b6b' : '#4b5563' }}
                onClick={() => setIsOpen(false)}
              >
                Sign In
              </a>
              <a
                href="/register"
                className="mt-2 px-4 py-3 rounded-full bg-[#22c55e] text-black font-medium text-center transition-all duration-300"
                onClick={() => setIsOpen(false)}
              >
                Start Free
              </a>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}