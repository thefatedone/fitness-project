"use client";
import { Heart } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";

const footerGroups = [
  {
    sectionKey: "product" as const,
    links: [
      { key: "features", href: "/#features" },
      { key: "pricing", href: "/#pricing" },
      { key: "aiRecognition", href: "#" },
      { key: "integrations", href: "#" },
    ],
  },
  {
    sectionKey: "company" as const,
    links: [
      { key: "about", href: "#" },
      { key: "blog", href: "#" },
      { key: "careers", href: "#" },
      { key: "contact", href: "#" },
    ],
  },
  {
    sectionKey: "legal" as const,
    links: [
      { key: "privacyPolicy", href: "#" },
      { key: "termsOfService", href: "#" },
      { key: "cookiePolicy", href: "#" },
      { key: "hipaa", href: "#" },
    ],
  },
];

export default function Footer() {
  const { t } = useTranslations("footer");
  const { theme } = useTheme();

  return (
    <footer
      className="w-full py-16 transition-colors duration-500 ease-in-out"
      style={{
        backgroundColor: theme === 'dark' ? 'var(--background)' : '#ffffff',
        borderTopWidth: '1px',
        borderTopStyle: 'solid',
        borderTopColor: theme === 'dark' ? '#1a1a1a' : '#e5e7eb',
      }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
          <div className="col-span-2 md:col-span-1">
            <a href="/" className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 rounded-lg bg-[#22c55e] flex items-center justify-center">
                <span className="text-black font-bold text-lg">N</span>
              </div>
              <span
                className="font-semibold text-lg"
                style={{ color: theme === 'dark' ? '#ffffff' : '#111827' }}
              >
                NutriMind
              </span>
            </a>
            <p className="text-sm" style={{ color: theme === 'dark' ? '#6b7280' : '#6b7280' }}>
              {t("tagline")}
            </p>
          </div>

          {footerGroups.map((group) => (
            <div key={group.sectionKey}>
              <h4 className="font-semibold mb-4" style={{ color: theme === 'dark' ? '#ffffff' : '#111827' }}>
                {t(group.sectionKey)}
              </h4>
              <ul className="space-y-3">
                {group.links.map((link) => (
                  <li key={link.key}>
                    <a
                      href={link.href}
                      className="text-sm transition-colors duration-500 ease-in-out"
                      style={{ color: theme === 'dark' ? '#6b7280' : '#6b7280' }}
                    >
                      {t(link.key)}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div
          className="flex flex-col md:flex-row items-center justify-between gap-4 pt-8"
          style={{
            borderTopWidth: '1px',
            borderTopStyle: 'solid',
            borderTopColor: theme === 'dark' ? '#1a1a1a' : '#e5e7eb',
          }}
        >
          <p className="text-sm flex items-center gap-1" style={{ color: theme === 'dark' ? '#6b7280' : '#6b7280' }}>
            {t("madeWith")} <Heart className="w-3 h-3 text-[#22c55e]" /> {t("byTeam")}
          </p>
          <p className="text-sm" style={{ color: theme === 'dark' ? '#525252' : '#9ca3af' }}>
            {t("copyright")}
          </p>
        </div>
      </div>
    </footer>
  );
}