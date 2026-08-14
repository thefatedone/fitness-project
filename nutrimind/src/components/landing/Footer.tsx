"use client";
import { Heart } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";

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

  return (
    <footer className="ln-section w-full py-16 border-t ln-divider">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
          <div className="col-span-2 md:col-span-1">
            <a href="/" className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 rounded-lg bg-[#22c55e] flex items-center justify-center">
                <span className="text-black font-bold text-lg">N</span>
              </div>
              <span className="ln-text font-semibold text-lg">NutriMind</span>
            </a>
            <p className="ln-text-muted text-sm">{t("tagline")}</p>
          </div>

          {footerGroups.map((group) => (
            <div key={group.sectionKey}>
              <h4 className="ln-text font-semibold mb-4">{t(group.sectionKey)}</h4>
              <ul className="space-y-3">
                {group.links.map((link) => (
                  <li key={link.key}>
                    <a href={link.href} className="ln-link text-sm">
                      {t(link.key)}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="flex flex-col md:flex-row items-center justify-between gap-4 pt-8 border-t ln-divider">
          <p className="ln-text-muted text-sm flex items-center gap-1">
            {t("madeWith")} <Heart className="w-3 h-3 text-[#22c55e]" /> {t("byTeam")}
          </p>
          <p className="ln-text-subtle text-sm">{t("copyright")}</p>
        </div>
      </div>
    </footer>
  );
}
