"use client";
import { motion } from "framer-motion";
import { Check } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";

const plans = [
  {
    nameKey: "free",
    price: "$0",
    periodKey: "forever",
    descKey: "freeDescription",
    featuresKeys: ["basicFoodLogging", "aiMessages100", "dailyMacroSummary", "communitySupport"],
    highlighted: false,
    ctaKey: "getStarted",
  },
  {
    nameKey: "pro",
    price: "$9.99",
    periodKey: "perMonth",
    descKey: "proDescription",
    featuresKeys: ["unlimitedFoodLogging", "unlimitedAiMessages", "advancedAnalytics", "mealPlanning", "prioritySupport"],
    highlighted: true,
    badgeKey: "mostPopular",
    ctaKey: "startFreeTrial",
  },
  {
    nameKey: "family",
    price: "$19.99",
    periodKey: "perMonth",
    descKey: "familyDescription",
    featuresKeys: ["everythingInPro", "upTo5Family", "sharedMealPlans", "familyDashboard", "dedicatedSupport"],
    highlighted: false,
    ctaKey: "startFamilyPlan",
  },
];

export default function Pricing() {
  const { t } = useTranslations("pricing");
  const { theme } = useTheme();

  return (
    <section
      id="pricing"
      className="w-full py-24 md:py-32 relative"
      style={{ backgroundColor: theme === 'light' ? '#f0fdf4' : 'var(--background)' }}
    >
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
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
          {plans.map((plan, index) => (
            <motion.div
              key={plan.nameKey}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className="relative p-6 rounded-2xl"
              style={
                plan.highlighted
                  ? {
                      backgroundColor: '#22c55e',
                      borderWidth: '2px',
                      borderStyle: 'solid',
                      borderColor: theme === 'dark' ? '#22c55e' : '#16a34a',
                      boxShadow: '0 0 60px -10px rgba(34,197,94,0.4)',
                    }
                  : {
                      backgroundColor: theme === 'light' ? '#ffffff' : 'var(--card)',
                      borderWidth: '1px',
                      borderStyle: 'solid',
                      borderColor: theme === 'light' ? '#e5e7eb' : 'var(--border)',
                      boxShadow: theme === 'light' ? '0 2px 8px rgba(0,0,0,0.06)' : 'none',
                    }
              }
            >
              {plan.badgeKey && (
                <div
                  className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-xs font-bold"
                  style={{
                    backgroundColor: plan.highlighted ? '#ffffff' : '#22c55e',
                    color: plan.highlighted ? '#16a34a' : '#000',
                  }}
                >
                  {t(plan.badgeKey)}
                </div>
              )}

              <div
                className="font-bold text-lg mb-1"
                style={{ color: plan.highlighted ? '#ffffff' : (theme === 'light' ? '#111827' : 'var(--foreground)') }}
              >
                {t(plan.nameKey)}
              </div>
              <div className="flex items-baseline gap-1 mb-2">
                <span
                  className="text-4xl font-black"
                  style={{ color: plan.highlighted ? '#ffffff' : (theme === 'light' ? '#111827' : 'var(--foreground)') }}
                >
                  {plan.price}
                </span>
                <span
                  className="text-sm"
                  style={{ color: plan.highlighted ? 'rgba(255,255,255,0.8)' : (theme === 'light' ? '#6b7280' : 'var(--foreground-muted)') }}
                >
                  {t(plan.periodKey)}
                </span>
              </div>
              <p
                className="text-sm mb-6"
                style={{ color: plan.highlighted ? '#f0fdf4' : (theme === 'light' ? '#6b7280' : 'var(--foreground-muted)') }}
              >
                {t(plan.descKey)}
              </p>

              <ul className="space-y-3 mb-8">
                {plan.featuresKeys.map((featureKey) => (
                  <li key={featureKey} className="flex items-start gap-3">
                    <Check
                      className="w-4 h-4 mt-0.5 flex-shrink-0"
                      style={{ color: plan.highlighted ? '#ffffff' : '#22c55e' }}
                      strokeWidth={2.5}
                    />
                    <span
                      className="text-sm"
                      style={{ color: plan.highlighted ? '#ffffff' : (theme === 'light' ? '#374151' : 'var(--foreground-muted)') }}
                    >
                      {t(featureKey)}
                    </span>
                  </li>
                ))}
              </ul>

              <button
                className="w-full py-3 rounded-full font-semibold text-sm transition-all duration-300 active:scale-[0.98]"
                style={
                  plan.highlighted
                    ? {
                        backgroundColor: '#ffffff',
                        color: '#16a34a',
                      }
                    : {
                        backgroundColor: theme === 'light' ? '#111827' : 'var(--background-secondary)',
                        color: theme === 'light' ? '#ffffff' : 'var(--foreground)',
                      }
                }
                onMouseEnter={e => {
                  if (!plan.highlighted) {
                    e.currentTarget.style.backgroundColor = theme === 'light' ? '#374151' : '#1a1a1a';
                  } else {
                    e.currentTarget.style.backgroundColor = '#f0fdf4';
                  }
                }}
                onMouseLeave={e => {
                  if (!plan.highlighted) {
                    e.currentTarget.style.backgroundColor = theme === 'light' ? '#111827' : 'var(--background-secondary)';
                  } else {
                    e.currentTarget.style.backgroundColor = '#ffffff';
                  }
                }}
              >
                {t(plan.ctaKey)}
              </button>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}