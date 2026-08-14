"use client";
import { motion } from "framer-motion";
import { Star } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";
import SectionHeading from "@/components/ui/SectionHeading";
import Card from "@/components/ui/Card";

const testimonials = [
  { image: "https://picsum.photos/seed/priya/200/200" },
  { image: "https://picsum.photos/seed/marcus/200/200" },
  { image: "https://picsum.photos/seed/sofia/200/200" },
];

export default function Testimonials() {
  const { t } = useTranslations("testimonials");

  return (
    <Section background="alt">
      <SectionHeading title={t("title")} subtitle={t("subtitle")} />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {testimonials.map((tData, index) => (
          <motion.div
            key={index}
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
          >
            <Card hover className="p-6 cursor-default">
              <div className="flex gap-1 mb-4">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} className="w-4 h-4 fill-[#facc15] text-[#facc15]" strokeWidth={0} />
                ))}
              </div>
              <p className="ln-text-muted text-sm leading-relaxed mb-6 italic">
                &ldquo;{t(`person${index + 1}Quote`)}&rdquo;
              </p>
              <div className="flex items-center gap-3">
                <img
                  src={tData.image}
                  alt={t(`person${index + 1}Name`)}
                  className="w-10 h-10 rounded-full object-cover"
                />
                <div>
                  <div className="ln-text text-sm font-semibold">{t(`person${index + 1}Name`)}</div>
                  <div className="ln-text-subtle text-xs">{t(`person${index + 1}Role`)}</div>
                </div>
              </div>
            </Card>
          </motion.div>
        ))}
      </div>
    </Section>
  );
}
