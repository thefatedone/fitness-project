"use client";
import { motion } from "framer-motion";

interface SectionHeadingProps {
  title: string;
  subtitle?: string;
  align?: "center" | "left";
  className?: string;
}

/**
 * Standard "title + subtitle" header used at the top of every landing section.
 * Title and subtitle fade in together when the heading scrolls into view.
 * (Previously this mapped the title into per-word motion.spans with a
 *  staggerChildren variant. The 3rd word sometimes got stuck at opacity 0
 *  when its parent re-rendered mid-animation (e.g. on language switch
 *  or layout shift), so it was simplified to a single fade-in — same
 *  visual feel, no stuck words.)
 */
export default function SectionHeading({
  title,
  subtitle,
  align = "center",
  className = "",
}: SectionHeadingProps) {
  const isCenter = align === "center";
  const alignClass = isCenter ? "text-center mx-auto" : "text-left";

  return (
    <div className={`mb-16 ${className}`}>
      <motion.h2
        className={`ln-heading text-4xl md:text-5xl tracking-tight mb-4 ${isCenter ? "text-center" : "text-left"}`}
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, margin: "-80px" }}
        transition={{ duration: 0.6, ease: [0.32, 0.72, 0, 1] }}
      >
        {title}
      </motion.h2>
      {subtitle && (
        <motion.p
          className={`ln-subheading max-w-2xl min-h-[3rem] ${alignClass}`}
          initial={{ opacity: 0, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5, delay: 0.5 }}
        >
          {subtitle}
        </motion.p>
      )}
    </div>
  );
}
