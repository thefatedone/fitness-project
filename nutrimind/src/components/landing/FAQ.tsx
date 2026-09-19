"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import Section from "@/components/ui/Section";
import SectionHeading from "@/components/ui/SectionHeading";
import Card from "@/components/ui/Card";

/**
 * Single-open FAQ accordion, placed right before the Contact
 * section so it can catch any remaining objections a user might
 * have before they reach for the email form. Visual language
 * matches the rest of the landing page — `Section` +
 * `SectionHeading` + `Card` primitives, no new design tokens.
 *
 * Behavioural notes:
 *  - First item is open by default (`useState<number | null>(0)`)
 *    so the section doesn't look completely empty on first scroll.
 *  - Only one item is open at a time; clicking the open one
 *    closes it. The chevron rotates 180° via Framer Motion's
 *    `animate` (transform-only — no layout jank, no `width` /
 *    `height` animation, per the design skill's hardware-accel
 *    rules).
 *  - Answer panels use `opacity` + `transform: translateY` for
 *    the in/out transition; the height is solved purely by the
 *    intrinsic size of the answer text. This keeps the
 *    animation on the GPU's compositor thread and avoids
 *    triggering layout on every frame.
 */

const FAQ_KEYS = [
  "diffPlans",
  "aiAccuracy",
  "dataPrivacy",
  "cancelAnytime",
  "freeForever",
  "aiTrainerLaunch",
] as const;

export default function FAQ() {
  // The hook capitalises the namespace → "FAQ", which matches the
  // top-level key in the messages bundles.
  const { t } = useTranslations("faq");
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <Section id="faq" background="default" containerClassName="max-w-3xl">
      <SectionHeading title={t("title")} subtitle={t("subtitle")} />

      <div className="flex flex-col gap-3">
        {FAQ_KEYS.map((key, index) => {
          const isOpen = openIndex === index;
          return (
            <Card key={key} className="overflow-hidden">
              <button
                type="button"
                onClick={() => setOpenIndex(isOpen ? null : index)}
                className="w-full flex items-center justify-between gap-4 p-5 text-left"
                aria-expanded={isOpen}
              >
                <span className="ln-text font-semibold text-sm md:text-base">
                  {t(`${key}Q`)}
                </span>
                <motion.div
                  animate={{ rotate: isOpen ? 180 : 0 }}
                  transition={{ duration: 0.25, ease: [0.32, 0.72, 0, 1] }}
                  className="flex-shrink-0"
                >
                  <ChevronDown className="w-4 h-4 text-[#22c55e]" />
                </motion.div>
              </button>
              <AnimatePresence initial={false}>
                {isOpen && (
                  <motion.div
                    // opacity + translateY stays on the GPU
                    // compositor — see module comment above.
                    initial={{ opacity: 0, y: -8 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -8 }}
                    transition={{ duration: 0.25, ease: [0.32, 0.72, 0, 1] }}
                  >
                    <p className="ln-text-muted text-sm leading-relaxed px-5 pb-5">
                      {t(`${key}A`)}
                    </p>
                  </motion.div>
                )}
              </AnimatePresence>
            </Card>
          );
        })}
      </div>
    </Section>
  );
}
