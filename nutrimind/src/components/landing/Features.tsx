"use client";
import { motion } from "framer-motion";
import { Brain, BarChart3, Target, Utensils, MessageCircle, TrendingUp } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";
import SectionHeading from "@/components/ui/SectionHeading";
import Card from "@/components/ui/Card";

const features = [
  { key: "aiCalorieRecognition", icon: Brain },
  { key: "smartDailyTracking", icon: BarChart3 },
  { key: "personalizedGoals", icon: Target },
  { key: "mealPlanning", icon: Utensils },
  { key: "aiCoach247", icon: MessageCircle },
  { key: "progressAnalytics", icon: TrendingUp },
];

export default function Features() {
  const { t } = useTranslations("features");

  return (
    <Section id="features" background="alt">
      <SectionHeading title={t("title")} subtitle={t("subtitle")} />

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {features.map(({ key, icon: Icon }, index) => {
          return (
            <motion.div
              key={key}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
            >
              <Card hover className="group p-6">
                <div className="ln-badge w-12 h-12 !border-0 rounded-xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300">
                  <Icon className="w-6 h-6 text-[#22c55e]" strokeWidth={1.5} />
                </div>
                <h3 className="ln-text text-lg font-semibold mb-2">{t(key)}</h3>
                <p className="ln-text-muted text-sm leading-relaxed">{t(`${key}Desc`)}</p>
              </Card>
            </motion.div>
          );
        })}
      </div>
    </Section>
  );
}
