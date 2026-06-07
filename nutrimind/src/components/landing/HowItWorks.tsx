"use client";
import { motion } from "framer-motion";
import { User, ForkKnife, Sparkles } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";

const steps = [
  { key: "step1", icon: User },
  { key: "step2", icon: ForkKnife },
  { key: "step3", icon: Sparkles },
];

export default function HowItWorks() {
  const { t } = useTranslations("howItWorks");
  const { theme } = useTheme();

  return (
    <section
      id="how-it-works"
      className="w-full py-24 md:py-32 relative"
      style={{ backgroundColor: theme === 'light' ? '#f0fdf4' : 'var(--background)' }}
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

        <div className="relative">
          <div
            className="hidden lg:block absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-2/3 h-px"
            style={{
              background: theme === 'light'
                ? 'linear-gradient(to right, transparent, #d1d5db, transparent)'
                : 'linear-gradient(to right, transparent, rgba(34,197,94,0.3), transparent)',
            }}
          />
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 lg:gap-12">
            {steps.map((step, index) => (
              <motion.div
                key={step.key}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: index * 0.2, ease: [0.32, 0.72, 0, 1] }}
                className="relative flex flex-col items-center text-center"
              >
                <div
                  className="w-16 h-16 rounded-full flex items-center justify-center mb-6 relative z-10"
                  style={{
                    backgroundColor: theme === 'light' ? '#ffffff' : 'var(--card)',
                    borderWidth: '1px',
                    borderStyle: 'solid',
                    borderColor: 'rgba(34, 197, 94, 0.3)',
                    boxShadow: theme === 'light' ? '0 2px 8px rgba(0,0,0,0.08)' : 'none',
                  }}
                >
                  <step.icon className="w-7 h-7 text-[#22c55e]" strokeWidth={1.5} />
                </div>
                <div className="absolute -top-2 -right-2 w-8 h-8 rounded-full bg-[#22c55e] flex items-center justify-center">
                  <span className="text-black text-xs font-bold">0{index + 1}</span>
                </div>
                <h3
                  className="text-xl font-bold mb-3"
                  style={{ color: theme === 'light' ? '#111827' : 'var(--foreground)' }}
                >
                  {t(`${step.key}Title`)}
                </h3>
                <p
                  className="text-sm leading-relaxed max-w-xs"
                  style={{ color: theme === 'light' ? '#6b7280' : 'var(--foreground-muted)' }}
                >
                  {t(`${step.key}Desc`)}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}