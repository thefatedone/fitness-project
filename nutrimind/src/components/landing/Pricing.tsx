"use client";
import { motion } from "framer-motion";
import { Check } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";
import SectionHeading from "@/components/ui/SectionHeading";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";

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

  return (
    <Section id="pricing" background="tint" containerClassName="max-w-5xl">
      <SectionHeading title={t("title")} subtitle={t("subtitle")} />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {plans.map((plan, index) => (
          <motion.div
            key={plan.nameKey}
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
          >
            <Card variant={plan.highlighted ? "highlighted" : "default"} className="relative p-6 h-full">
              {plan.badgeKey && (
                <div
                  className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-xs font-bold"
                  style={{
                    backgroundColor: plan.highlighted ? "#ffffff" : "#22c55e",
                    color: plan.highlighted ? "#16a34a" : "#000",
                  }}
                >
                  {t(plan.badgeKey)}
                </div>
              )}

              <div className={`font-bold text-lg mb-1 ${plan.highlighted ? "text-white" : "ln-text"}`}>
                {t(plan.nameKey)}
              </div>
              <div className="flex items-baseline gap-1 mb-2">
                <span className={`text-4xl font-black ${plan.highlighted ? "text-white" : "ln-text"}`}>
                  {plan.price}
                </span>
                <span className={`text-sm ${plan.highlighted ? "text-white/80" : "ln-text-muted"}`}>
                  {t(plan.periodKey)}
                </span>
              </div>
              <p className={`text-sm mb-6 ${plan.highlighted ? "text-[#f0fdf4]" : "ln-text-muted"}`}>
                {t(plan.descKey)}
              </p>

              <ul className="space-y-3 mb-8">
                {plan.featuresKeys.map((featureKey) => (
                  <li key={featureKey} className="flex items-start gap-3">
                    <Check
                      className="w-4 h-4 mt-0.5 flex-shrink-0"
                      style={{ color: plan.highlighted ? "#ffffff" : "#22c55e" }}
                      strokeWidth={2.5}
                    />
                    <span className={`text-sm ${plan.highlighted ? "text-white" : "ln-text-muted"}`}>
                      {t(featureKey)}
                    </span>
                  </li>
                ))}
              </ul>

              <Button
                variant={plan.highlighted ? "onBrand" : "dark"}
                className="w-full !px-0 !py-3 text-sm"
              >
                {t(plan.ctaKey)}
              </Button>
            </Card>
          </motion.div>
        ))}
      </div>
    </Section>
  );
}
