"use client";
import { motion } from "framer-motion";
import { Brain, BarChart3, Target, Utensils, MessageCircle, TrendingUp } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";

const icons = { Brain, BarChart3, Target, Utensils, MessageCircle, TrendingUp };

const featureKeys = [
  "aiCalorieRecognition",
  "smartDailyTracking",
  "personalizedGoals",
  "mealPlanning",
  "aiCoach247",
  "progressAnalytics",
];

export default function Features() {
  const { t } = useTranslations("features");
  const { theme } = useTheme();

  return (
    <section
      id="features"
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

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {featureKeys.map((key, index) => {
            const Icon = icons[key as keyof typeof icons];
            return (
              <motion.div
                key={key}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
                className="group p-6 rounded-2xl hover:-translate-y-1 transition-all duration-300"
                style={{
                  backgroundColor: theme === 'light' ? '#f9fafb' : 'var(--card)',
                  borderWidth: '1px',
                  borderStyle: 'solid',
                  borderColor: theme === 'light' ? '#e5e7eb' : 'var(--border)',
                  boxShadow: theme === 'light' ? '0 1px 3px rgba(0,0,0,0.05)' : 'none',
                }}
                onMouseEnter={e => {
                  if (theme === 'light') {
                    e.currentTarget.style.borderColor = '#4ade80';
                    e.currentTarget.style.boxShadow = '0 10px 25px -5px rgba(34, 197, 94, 0.1), 0 8px 10px -6px rgba(0,0,0,0.1)';
                  }
                }}
                onMouseLeave={e => {
                  if (theme === 'light') {
                    e.currentTarget.style.borderColor = '#e5e7eb';
                    e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.05)';
                  }
                }}
              >
                <div
                  className="w-12 h-12 rounded-xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300"
                  style={{ backgroundColor: theme === 'light' ? '#f0fdf4' : 'rgba(34,197,94,0.1)' }}
                >
                  <Icon className="w-6 h-6 text-[#22c55e]" strokeWidth={1.5} />
                </div>
                <h3
                  className="text-lg font-semibold mb-2"
                  style={{ color: theme === 'light' ? '#111827' : 'var(--foreground)' }}
                >
                  {t(key)}
                </h3>
                <p
                  className="text-sm leading-relaxed"
                  style={{ color: theme === 'light' ? '#6b7280' : 'var(--foreground-muted)' }}
                >
                  {t(`${key}Desc`)}
                </p>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}