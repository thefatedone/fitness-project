"use client";
import { motion } from "framer-motion";
import { User, ForkKnife, Sparkles } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";
import SectionHeading from "@/components/ui/SectionHeading";

const steps = [
  { key: "step1", icon: User },
  { key: "step2", icon: ForkKnife },
  { key: "step3", icon: Sparkles },
];

export default function HowItWorks() {
  const { t } = useTranslations("howItWorks");

  return (
    <Section id="how-it-works" background="tint">
      <SectionHeading title={t("title")} subtitle={t("subtitle")} />

      <div className="relative">
        <div className="hidden lg:block absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-2/3 h-px">
          <div className="ln-divider absolute inset-0 border-t border-dashed opacity-60" />
          <motion.div
            className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-[#22c55e]"
            style={{ boxShadow: "0 0 8px rgba(34,197,94,0.8)" }}
            animate={{ left: ["0%", "100%"] }}
            transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
          />
        </div>

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
              <div className="relative inline-block mb-6">
                <div className="ln-card w-20 h-20 rounded-2xl flex items-center justify-center relative z-10 !border-[rgba(34,197,94,0.3)]">
                  <span className="absolute top-2.5 left-2.5 w-1.5 h-1.5 rounded-full bg-[#22c55e] animate-pulse" />
                  <step.icon className="w-7 h-7 text-[#22c55e]" strokeWidth={1.5} />
                </div>
                <div className="absolute -top-2 -right-2 w-8 h-8 rounded-full bg-[#22c55e] flex items-center justify-center z-20">
                  <span className="text-black text-xs font-bold">0{index + 1}</span>
                </div>
              </div>
              <h3 className="ln-text text-xl font-bold mb-3">{t(`${step.key}Title`)}</h3>
              <p className="ln-text-muted text-sm leading-relaxed max-w-xs">{t(`${step.key}Desc`)}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </Section>
  );
}
