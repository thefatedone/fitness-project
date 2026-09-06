"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Menu, X } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Button from "@/components/ui/Button";

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const { t } = useTranslations("navbar");

  const navLinks = [
    { href: "#features", label: t("features") },
    { href: "#pricing", label: t("pricing") },
  ];

  return (
    <>
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
    </>
  );
}
