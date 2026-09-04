"use client";
import { motion } from "framer-motion";
import { Brain, BarChart3, Target, Utensils, MessageCircle, TrendingUp } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";
import SectionHeading from "@/components/ui/SectionHeading";
import Card from "@/components/ui/Card";

const features = [
  { key: "aiCalorieRecognition", icon: Brain, featured: false },
  { key: "smartDailyTracking", icon: BarChart3, featured: false },
  { key: "personalizedGoals", icon: Target, featured: false },
  { key: "mealPlanning", icon: Utensils, featured: false },
  { key: "aiCoach247", icon: MessageCircle, featured: true },
  { key: "progressAnalytics", icon: TrendingUp, featured: true },
];

/** Tiny decorative sparkline used inside the "progress"-flavoured featured card. */
function MiniSparkline() {
  return (
    <svg viewBox="0 0 120 32" className="w-full h-8 mt-4" fill="none">
      <polyline
        points="0,26 20,22 40,24 60,14 80,16 100,6 120,8"
        stroke="#22c55e"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="120" cy="8" r="3" fill="#22c55e" />
    </svg>
  );
}

/** Tiny decorative chat-bubble stack used inside the "AI chat"-flavoured featured card. */
function MiniChatBubbles() {
  return (
    <div className="mt-4 flex flex-col gap-1.5">
      <div className="ln-badge !border-0 self-start rounded-full rounded-bl-sm px-3 py-1.5 text-xs max-w-[70%]">
        &bull;&bull;&bull;
      </div>
      <div className="self-end rounded-full rounded-br-sm px-3 py-1.5 text-xs max-w-[55%] bg-[#22c55e] text-black font-medium">
        ok
      </div>
    </div>
  );
}

export default function Features() {
  const { t } = useTranslations("features");

  return (
    <Section id="features" background="alt">
      <SectionHeading title={t("title")} subtitle={t("subtitle")} />

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {features.map(({ key, icon: Icon, featured }, index) => (
          <motion.div
            key={key}
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            whileHover={{ y: -6, rotate: index % 2 === 0 ? -0.6 : 0.6 }}
            transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
            className={featured ? "md:col-span-2 lg:col-span-1" : ""}
          >
            <Card hover className="group relative overflow-hidden p-6 h-full">
              <div
                className="absolute -top-8 -right-8 w-28 h-28 rounded-full bg-[#22c55e] opacity-0 group-hover:opacity-[0.08] blur-2xl transition-opacity duration-500 pointer-events-none"
              />

              <div
                className={`ln-badge !border-0 rounded-xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300 ${
                  featured ? "w-14 h-14" : "w-12 h-12"
                }`}
              >
                <Icon className={featured ? "w-7 h-7 text-[#22c55e]" : "w-6 h-6 text-[#22c55e]"} strokeWidth={1.5} />
              </div>
              <h3 className={`ln-text font-semibold mb-2 ${featured ? "text-xl" : "text-lg"}`}>{t(key)}</h3>
              <p className="ln-text-muted text-sm leading-relaxed">{t(`${key}Desc`)}</p>

              {key === "progressAnalytics" && <MiniSparkline />}
              {key === "aiCoach247" && <MiniChatBubbles />}
            </Card>
          </motion.div>
        ))}
      </div>
    </Section>
  );
}
