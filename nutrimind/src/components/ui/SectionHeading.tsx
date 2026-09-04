"use client";
import { motion } from "framer-motion";

interface SectionHeadingProps {
  title: string;
  subtitle?: string;
  align?: "center" | "left";
  className?: string;
}

const container = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.045 },
  },
};

const word = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.32, 0.72, 0, 1] as [number, number, number, number] },
  },
};

/**
 * Standard "title + subtitle" header used at the top of every landing section.
 * Title words stagger in on scroll into view; subtitle fades in right after.
 */
export default function SectionHeading({
  title,
  subtitle,
  align = "center",
  className = "",
}: SectionHeadingProps) {
  const alignClass = align === "center" ? "text-center mx-auto" : "text-left";
  const words = title.split(" ");

  return (
    <div className={`mb-16 ${align === "center" ? "text-center" : ""} ${className}`}>
      <motion.h2
        className="ln-heading text-4xl md:text-5xl tracking-tight mb-4"
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={container}
      >
        {words.map((w, i) => (
          <motion.span key={i} variants={word} className="inline-block mr-[0.25em]">
            {w}
          </motion.span>
        ))}
      </motion.h2>
      {subtitle && (
        <motion.p
          className={`ln-subheading max-w-2xl ${alignClass}`}
          initial={{ opacity: 0, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5, delay: words.length * 0.045 + 0.1 }}
        >
          {subtitle}
        </motion.p>
      )}
    </div>
  );
}
