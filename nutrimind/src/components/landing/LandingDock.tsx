"use client";
import { useState, useEffect, useRef } from "react";
import {
  Home,
  Sun,
  Moon,
  Globe,
  Sparkles,
  Tag,
  LogIn,
  User,
  Rocket,
} from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import Dock, { type DockItemData } from "@/components/ui/Dock";
import {
  useLanguage,
  type Locale,
} from "@/context/LanguageContext";
import { useTheme } from "@/context/ThemeContext";
import { useAuth } from "@/context/AuthContext";
import { useTranslations } from "@/hooks/useTranslations";

const LANGS: { code: Locale; label: string }[] = [
  { code: "en", label: "EN" },
  { code: "ka", label: "KA" },
  { code: "ru", label: "RU" },
];

/**
 * Floating landing-page dock. Eight controls, always one tap away.
 *
 * Items inherited from the original dock:
 *   - Home       → smooth-scrolls the page back to the top
 *   - Globe      → toggles the language popover (EN / KA / RU)
 *   - Sun/Moon   → flips between dark and light themes
 *
 * Items migrated from the (now-deleted) Navbar:
 *   - Sparkles   → smooth-scrolls to #features
 *   - Tag        → smooth-scrolls to #pricing
 *   - LogIn/User → explicit auth action (sign in or go to /dashboard/profile,
 *                  depending on state — sign-out is intentionally NOT reachable
 *                  from the landing page; the user must be in /dashboard to log out)
 *   - Rocket     → the primary CTA — navigates to /register
 *
 * The dock is the SOLE place for navigation, theme switching, language,
 * and auth on the landing page — the entire Navbar was removed and the
 * logo was extracted into its own top-left component (see BrandLogo).
 *
 * The dock itself is the React Bits <Dock /> component (provides the
 * macOS-style magnification-on-hover). This wrapper layers the language
 * popover ABOVE the dock using `position: fixed` so it floats cleanly
 * regardless of the wrap div's layout.
 *
 * After any button press we briefly pin the corresponding label visible
 * (via Dock's `forceVisibleIndex` prop) so the user gets a clear,
 * localised confirmation of what they just triggered.
 */
export default function LandingDock() {
  const { locale, setLocale } = useLanguage();
  const { theme, toggleTheme } = useTheme();
  const { isAuthenticated, signIn } = useAuth();
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

  const scrollToSection = (id: string) => {
    if (typeof window === "undefined") return;
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    } else {
      // Fallback if the section isn't mounted yet (race during first paint)
      window.location.hash = `#${id}`;
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
      icon: <Sparkles size={20} strokeWidth={1.8} />,
      label: td("features"),
      onClick: () => {
        pinLabel(1);
        scrollToSection("features");
      },
    },
    {
      icon: <Tag size={20} strokeWidth={1.8} />,
      label: td("pricing"),
      onClick: () => {
        pinLabel(2);
        scrollToSection("pricing");
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
        pinLabel(3);
        toggleTheme();
      },
    },
    {
      icon: <Globe size={20} strokeWidth={1.8} />,
      label: td("language"),
      onClick: () => {
        pinLabel(4);
        setShowLangs((v) => !v);
      },
    },
    {
      icon: isAuthenticated ? (
        <User size={20} strokeWidth={1.8} />
      ) : (
        <LogIn size={20} strokeWidth={1.8} />
      ),
      label: isAuthenticated ? td("profile") : td("signIn"),
      onClick: () => {
        pinLabel(5);
        if (isAuthenticated) {
          goToProfile();
        } else {
          signIn();
        }
      },
    },
    {
      icon: <Rocket size={20} strokeWidth={1.8} />,
      label: td("startFree"),
      onClick: () => {
        pinLabel(6);
        if (typeof window !== "undefined") {
          window.location.href = "/register";
        }
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
        panelHeight={68}
        baseItemSize={50}
        magnification={70}
        forceVisibleIndex={pinnedIndex}
      />
    </div>
  );
}
