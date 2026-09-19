"use client";

import { motion } from "framer-motion";
import { ShieldCheck, Lock, Trash2 } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";

/**
 * Compact 3-point trust band placed right before Pricing, where
 * the user is about to be asked for payment. The three claims
 * (no-selling, encryption, delete-anytime) are the most common
 * objections at the purchase decision moment — surfacing them
 * one screen upstream of Pricing drops the friction back to "I'll
 * scroll back and check" rather than "I'll leave and look at
 * the privacy policy."
 *
 * The skill recommends avoiding the 3-equal-column-card layout
 * because it's an AI-cliché pattern in feature rows, but this is
 * not a feature row — it's a trust signal band with identical
 * weight per item, and breaking it into 2-column zig-zag would
 * suggest a hierarchy (one item matters more than the others)
 * that doesn't exist. The 3 columns stay; the visual treatment
 * deliberately borrows the project's `ln-badge` style rather
 * than introducing another card type.
 */

const POINTS = [
  { key: "noSell", icon: ShieldCheck },
  { key: "encrypted", icon: Lock },
  { key: "deleteAnytime", icon: Trash2 },
] as const;

export default function PrivacySection() {
  const { t } = useTranslations("privacy");

  return (
    <Section background="alt" className="!py-16 md:!py-20">
      <div className="text-center max-w-2xl mx-auto mb-12">
        <h2 className="ln-heading text-2xl md:text-3xl tracking-tight mb-3">
          {t("title")}
        </h2>
        <p className="ln-subheading">{t("subtitle")}</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-4xl mx-auto">
        {POINTS.map(({ key, icon: Icon }, index) => (
          <motion.div
            key={key}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{
              duration: 0.5,
              delay: index * 0.1,
              ease: [0.32, 0.72, 0, 1],
            }}
            className="flex flex-col items-center text-center gap-3"
          >
            <div className="ln-badge !border-0 w-12 h-12 rounded-xl flex items-center justify-center">
              <Icon
                className="w-6 h-6 text-[#22c55e]"
                strokeWidth={1.5}
              />
            </div>
            <h3 className="ln-text font-semibold text-sm">
              {t(`${key}Title`)}
            </h3>
            <p className="ln-text-muted text-xs leading-relaxed max-w-[220px]">
              {t(`${key}Desc`)}
            </p>
          </motion.div>
        ))}
      </div>
    </Section>
  );
}
