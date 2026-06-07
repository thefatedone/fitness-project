"use client";
import { motion } from "framer-motion";
import { Star } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";

const testimonials = [
  { image: "https://picsum.photos/seed/priya/200/200" },
  { image: "https://picsum.photos/seed/marcus/200/200" },
  { image: "https://picsum.photos/seed/sofia/200/200" },
];

export default function Testimonials() {
  const { t } = useTranslations("testimonials");
  const { theme } = useTheme();

  return (
    <section
      className="w-full py-24 md:py-32 relative"
      style={{ backgroundColor: theme === 'light' ? '#ffffff' : 'var(--background-secondary)' }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2
            className="text-4xl md:text-5xl font-black tracking-tight mb-4"
            style={{ color: theme === 'light' ? '#111827' : 'var(--foreground)' }}
          >
            {t("title")}
          </h2>
          <p
            className="max-w-2xl mx-auto"
            style={{ color: theme === 'light' ? '#6b7280' : 'var(--foreground-muted)' }}
          >
            {t("subtitle")}
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {testimonials.map((tData, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className="p-6 rounded-2xl transition-all duration-300 cursor-default"
              style={{
                backgroundColor: theme === 'light' ? '#f9fafb' : 'var(--card)',
                borderWidth: '1px',
                borderStyle: 'solid',
                borderColor: theme === 'light' ? '#e5e7eb' : 'var(--border)',
              }}
              onMouseEnter={e => {
                if (theme === 'light') {
                  e.currentTarget.style.borderColor = '#86efac';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.08)';
                }
              }}
              onMouseLeave={e => {
                if (theme === 'light') {
                  e.currentTarget.style.borderColor = '#e5e7eb';
                  e.currentTarget.style.boxShadow = 'none';
                }
              }}
            >
              <div className="flex gap-1 mb-4">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} className="w-4 h-4 fill-[#facc15] text-[#facc15]" strokeWidth={0} />
                ))}
              </div>
              <p
                className="text-sm leading-relaxed mb-6 italic"
                style={{ color: theme === 'light' ? '#374151' : 'var(--foreground-muted)' }}
              >
                &ldquo;{t(`person${index + 1}Quote`)}&rdquo;
              </p>
              <div className="flex items-center gap-3">
                <img
                  src={tData.image}
                  alt={t(`person${index + 1}Name`)}
                  className="w-10 h-10 rounded-full object-cover"
                />
                <div>
                  <div
                    className="text-sm font-semibold"
                    style={{ color: theme === 'light' ? '#111827' : 'var(--foreground)' }}
                  >
                    {t(`person${index + 1}Name`)}
                  </div>
                  <div
                    className="text-xs"
                    style={{ color: theme === 'light' ? '#6b7280' : 'var(--foreground-subtle)' }}
                  >
                    {t(`person${index + 1}Role`)}
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}