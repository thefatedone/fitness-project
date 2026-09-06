"use client";
import { useState, useEffect, useRef } from "react";
import { Home, Sun, Moon, User, Globe } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import Dock, { type DockItemData } from "@/components/ui/Dock";
import {
  useLanguage,
  type Locale,
} from "@/context/LanguageContext";
import { useTheme } from "@/context/ThemeContext";
import { useTranslations } from "@/hooks/useTranslations";

const LANGS: { code: Locale; label: string }[] = [
  { code: "en", label: "EN" },
  { code: "ka", label: "KA" },
  { code: "ru", label: "RU" },
];

/**
 * Floating landing-page dock. Four controls, always one tap away:
 *   - Home       → smooth-scrolls the page back to the top
 *   - Globe      → toggles the language popover (EN / KA / RU)
 *   - Sun/Moon   → flips between dark and light themes
 *   - User       → navigates to /dashboard/profile (the dashboard itself
 *                  redirects to /login if the visitor isn't authenticated)
 *
 * The dock is the SOLE place for theme switching on the landing page —
 * the Navbar's toggle has been removed so the control surface is one tap
 * away regardless of which section the visitor is reading.
 *
 * The dock itself is the React Bits <Dock /> component (provides the
 * macOS-style magnification-on-hover). This wrapper layers the language
 * popover ABOVE the dock using `position: fixed` so it floats cleanly
 * regardless of the wrap div's layout (the inner Dock itself is
 * fixed-positioned, so an `absolute` popover inside the wrap div was
 * rendered off-screen below the dock).
 *
 * After any button press we briefly pin the corresponding label visible
 * (via Dock's `forceVisibleIndex` prop) so the user gets a clear,
 * localised confirmation of what they just triggered — without
 * re-introducing the bfcache-focus bug that kept the tooltip pinned
 * when returning from another page.
 */
export default function LandingDock() {
  const { locale, setLocale } = useLanguage();
  const { theme, toggleTheme } = useTheme();
  const { t: td } = useTranslations("dock");
  const [showLangs, setShowLangs] = useState(false);
  const [pinnedIndex, setPinnedIndex] = useState<number | null>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const pinTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Click-outside to close the language popover
  useEffect(() => {
    if (!showLangs) return;
    const handler = (e: MouseEvent) => {
      if (
        wrapRef.current &&
        !wrapRef.current.contains(e.target as Node)
      ) {
        setShowLangs(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [showLangs]);

  // Clear any pending pin timeout when the component unmounts.
  useEffect(() => {
    return () => {
      if (pinTimeoutRef.current) clearTimeout(pinTimeoutRef.current);
    };
  }, []);

  const pinLabel = (index: number) => {
    setPinnedIndex(index);
    if (pinTimeoutRef.current) clearTimeout(pinTimeoutRef.current);
    pinTimeoutRef.current = setTimeout(() => {
      setPinnedIndex(null);
      pinTimeoutRef.current = null;
    }, 2400);
  };

  const scrollToTop = () => {
    if (typeof window !== "undefined") {
      window.scrollTo({ top: 0, left: 0, behavior: "smooth" });
    }
  };

  const goToProfile = () => {
    if (typeof window !== "undefined") {
      window.location.href = "/dashboard/profile";
    }
  };

  const items: DockItemData[] = [
    {
      icon: <Home size={20} strokeWidth={1.8} />,
      label: td("home"),
      onClick: () => {
        pinLabel(0);
        scrollToTop();
      },
    },
    {
      icon: <Globe size={20} strokeWidth={1.8} />,
      label: td("language"),
      onClick: () => {
        pinLabel(1);
        setShowLangs((v) => !v);
      },
    },
    {
      icon:
        theme === "dark" ? (
          <Sun size={20} strokeWidth={1.8} />
        ) : (
          <Moon size={20} strokeWidth={1.8} />
        ),
      label: theme === "dark" ? td("lightMode") : td("darkMode"),
      onClick: () => {
        pinLabel(2);
        toggleTheme();
      },
    },
    {
      icon: <User size={20} strokeWidth={1.8} />,
      label: td("profile"),
      onClick: () => {
        pinLabel(3);
        goToProfile();
      },
    },
  ];

  return (
    <div ref={wrapRef} className="relative">
      <AnimatePresence>
        {showLangs && (
          <motion.div
            initial={{ opacity: 0, y: 10, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10, scale: 0.95 }}
            transition={{ duration: 0.18, ease: "easeOut" }}
            className="fixed bottom-[112px] left-1/2 -translate-x-1/2 z-50 flex items-center gap-1 rounded-full p-1.5 backdrop-blur-xl border shadow-xl"
            style={{
              backgroundColor: "var(--dock-bg)",
              borderColor: "var(--dock-border)",
              boxShadow:
                "0 12px 32px -8px rgba(0, 0, 0, 0.35), 0 2px 6px -1px rgba(0, 0, 0, 0.12)",
            }}
            role="dialog"
            aria-label="Switch language"
          >
            {LANGS.map((lang) => {
              const isActive = locale === lang.code;
              return (
                <button
                  key={lang.code}
                  type="button"
                  onClick={() => {
                    setLocale(lang.code);
                    setShowLangs(false);
                  }}
                  aria-pressed={isActive}
                  className="px-4 py-1.5 rounded-full text-xs font-semibold transition-colors duration-150"
                  style={{
                    backgroundColor: isActive ? "#22c55e" : "transparent",
                    color: isActive ? "#000000" : "var(--foreground-muted)",
                  }}
                >
                  {lang.label}
                </button>
              );
            })}
          </motion.div>
        )}
      </AnimatePresence>

      <Dock
        items={items}
        panelHeight={80}
        baseItemSize={50}
        magnification={70}
        forceVisibleIndex={pinnedIndex}
      />
    </div>
  );
}
