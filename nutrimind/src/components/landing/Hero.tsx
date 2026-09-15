"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import { ArrowRight, Beef, ChevronDown, Droplet, Wheat } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useLanguage } from "@/context/LanguageContext";
import { useTheme } from "@/context/ThemeContext";
import Button from "@/components/ui/Button";

const FOOD_IMAGE_DARK = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80";
const FOOD_IMAGE_LIGHT = "/food-light.png";

// Animated stroke-ring chart, 64×64 viewBox, sized for the macro pillars
// (icon sits inside the ring). Track is drawn faintly with var(--border)
// (works on both themes); the colored arc animates strokeDashoffset from
// full to the progress value via framer-motion. The macro-pillar row uses
// `key={locale}` to re-trigger the animation on language switches.
const RING_RADIUS = 26;
const RING_CIRC = 2 * Math.PI * RING_RADIUS;

export default function Hero() {
  const { t } = useTranslations("hero");
  const { locale } = useLanguage();
  const { theme } = useTheme();
  const sectionRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end start"],
  });
  const parallaxY = useTransform(scrollYProgress, [0, 1], [0, 140]);

  const stats = [
    { val: "10M+", label: t("mealsTracked") },
    { val: "98%", label: t("aiAccuracy") },
    { val: "50K+", label: t("activeUsers") },
  ];

  // Three macro pillars (Protein / Carbs / Fat) rendered below the food
  // photo card. Each carries a Lucide icon in its own color, a consumed
  // value, and a percent that drives the per-pillar ring's animated
  // strokeDashoffset. Defined at the top of the component so the labels
  // can pick up fresh `t()` values on every locale change.
  const macros = [
    {
      key: "protein",
      label: t("protein"),
      consumed: 30,
      goal: 150,
      color: "#3b82f6",
      Icon: Beef,
      percent: 30 / 150,
    },
    {
      key: "carbs",
      label: t("carbs"),
      consumed: 45,
      goal: 200,
      color: "#f97316",
      Icon: Wheat,
      percent: 45 / 200,
    },
    {
      key: "fat",
      label: t("fat"),
      consumed: 12,
      goal: 65,
      color: "#a855f7",
      Icon: Droplet,
      percent: 12 / 65,
    },
  ];

  return (
    <section ref={sectionRef} className="w-full min-h-[100dvh] flex items-center relative overflow-hidden pt-16 ln-section-tint">
      <style>{`
        @keyframes scan {
          0%   { top: 0%; transform: translateY(0); }
          100% { top: 100%; transform: translateY(-100%); }
        }
      `}</style>

      <div className="max-w-[88rem] ml-[max(1.5rem,4vw)] mr-auto pl-4 sm:pl-6 lg:pl-8 pr-0 w-full">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          <motion.div
            initial={{ opacity: 0, x: -40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, ease: [0.32, 0.72, 0, 1] }}
            className="text-center lg:text-left"
          >
            <div className="ln-badge inline-flex items-center gap-2 px-3 py-1.5 rounded-full mb-8">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#22c55e] opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-[#22c55e]" />
              </span>
              <span className="ln-display text-sm font-medium">{t("badge")}</span>
            </div>

            <h1 className="ln-heading text-5xl md:text-6xl lg:text-7xl lg:max-w-[34rem] 2xl:text-8xl 2xl:max-w-[42rem] leading-[1.05] mb-6">
              <span className={`block ${locale === "ka" || locale === "ru" ? "whitespace-nowrap" : ""}`}>{t("headline1")}</span>
              <span className={`block ${locale === "ka" || locale === "ru" ? "whitespace-nowrap" : ""}`}>{t("headline2")}</span>
              <span className="block ln-eyebrow" style={{ textShadow: theme === "dark" ? "0 0 40px rgba(34,197,94,0.4)" : "none" }}>
                {t("headline3")}
              </span>
            </h1>

            <p className="ln-text-muted text-lg max-w-xl mx-auto lg:mx-0 mb-10 min-h-[6.5rem] md:min-h-[5rem]">
              {t("subtitle")}
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <Button href="/register" variant="primary" magnetic>
                {t("cta")} <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </Button>
              <Button href="#how-it-works" variant="secondary">
                {t("ctaSecondary")}
              </Button>
            </div>

            <div className="flex flex-wrap gap-8 mt-12 justify-center lg:justify-start">
              {stats.map(({ val, label }) => (
                <div key={label}>
                  <div className="ln-text ln-display text-2xl font-bold leading-none mb-1.5">{val}</div>
                  <div className="ln-text-muted text-sm min-h-[2.5rem] max-w-[10ch]">{label}</div>
                </div>
              ))}
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.32, 0.72, 0, 1] }}
            style={{ y: parallaxY }}
            className="flex justify-center lg:justify-end lg:pr-12 xl:pr-16 relative"
          >
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none -z-10">
              <div
                style={{
                  width: "420px",
                  height: "420px",
                  background: "radial-gradient(circle, rgba(34,197,94,0.22) 0%, transparent 70%)",
                  filter: "blur(70px)",
                }}
              />
            </div>

            <div className="relative flex flex-col gap-5 items-start w-full max-w-[400px]">
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                className="relative overflow-hidden flex-shrink-0 bg-black border border-[#1a1a1a] w-full"
                style={{
                  height: "440px",
                  borderRadius: "1.5rem",
                  boxShadow: "inset 0 0 80px 24px rgba(0,0,0,0.9), inset 0 0 160px 48px rgba(0,0,0,0.5)",
                }}
              >
                <img
                  src={theme === "dark" ? FOOD_IMAGE_DARK : FOOD_IMAGE_LIGHT}
                  alt="Healthy meal"
                  className="w-full h-full"
                  style={{ objectFit: "cover" }}
                />
                <div
                  className="absolute left-0 w-full h-0.5"
                  style={{
                    backgroundColor: "#22c55e",
                    boxShadow: "0 0 16px rgba(34,197,94,1), 0 0 40px rgba(34,197,94,0.5)",
                    animation: "scan 2.2s linear infinite",
                  }}
                />
                <div
                  className="absolute top-4 left-4 flex items-center gap-2 bg-black/70 backdrop-blur-sm text-green-400 text-xs px-3 py-1.5 rounded-full"
                  style={{ fontFamily: "'Comfortaa', sans-serif", fontFeatureSettings: "normal" }}
                >
                  <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                  {t("analyzingBadge")}
                </div>
                <div
                  className="ln-display absolute bottom-4 left-4 flex items-center gap-1.5 bg-black/80 backdrop-blur-sm border border-white/10 text-white text-sm font-medium px-3 py-1.5 rounded-full"
                  style={{ fontFamily: "'Comfortaa', sans-serif", fontFeatureSettings: "normal" }}
                >
                  🔥 403 {t("calorieUnit")}
                </div>
              </motion.div>

              {/* Three macro pillars — `key={locale}` re-mounts the row on
                  every language switch, which replays the per-pillar ring
                  strokeDashoffset animation. Each pillar floats on its
                  own staggered cycle so the cluster breathes naturally
                  instead of all three moving in lockstep. */}
              <div key={locale} className="grid grid-cols-3 gap-3 w-full">
                {macros.map((macro, i) => (
                  <motion.div
                    key={macro.key}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: [0, -6, 0] }}
                    transition={{
                      opacity: { duration: 0.5, delay: 0.6 + i * 0.1 },
                      y: { duration: 3.5 + i * 0.3, repeat: Infinity, ease: "easeInOut", delay: 0.6 + i * 0.2 },
                    }}
                    whileHover={{ y: -4 }}
                    className="ln-card-solid group relative rounded-2xl p-4 flex flex-col items-center text-center cursor-pointer overflow-hidden transition-colors duration-300 hover:border-[var(--color-brand)]"
                    style={{
                      minHeight: "190px",
                      borderColor: "var(--border)",
                      borderWidth: "1px",
                      boxShadow:
                        "inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px -12px rgba(0,0,0,0.4)",
                    }}
                  >
                    {/* Subtle macro-tinted wash — sits behind the card
                        content, only visible on hover so the resting state
                        stays neutral. */}
                    <div
                      aria-hidden
                      className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500"
                      style={{
                        background: `radial-gradient(circle at 50% 0%, ${macro.color}22, transparent 70%)`,
                      }}
                    />

                    {/* Icon ring — track + animated progress arc in the
                        macro's own color. SVG is rotated -90deg so the
                        dash animation starts from 12 o'clock. */}
                    <div className="relative w-14 h-14 mb-3">
                      <svg
                        viewBox="0 0 64 64"
                        className="absolute inset-0"
                        aria-hidden="true"
                        style={{ transform: "rotate(-90deg)" }}
                      >
                        <circle
                          cx={32}
                          cy={32}
                          r={26}
                          fill="none"
                          stroke="var(--border)"
                          strokeOpacity={0.5}
                          strokeWidth={3}
                        />
                        <motion.circle
                          cx={32}
                          cy={32}
                          r={26}
                          fill="none"
                          stroke={macro.color}
                          strokeWidth={3}
                          strokeLinecap="round"
                          strokeDasharray={RING_CIRC}
                          initial={{ strokeDashoffset: RING_CIRC }}
                          animate={{ strokeDashoffset: RING_CIRC * (1 - macro.percent) }}
                          transition={{ duration: 1.1, delay: 0.6 + i * 0.12, ease: "easeOut" }}
                        />
                      </svg>
                      <div
                        className="absolute inset-0 flex items-center justify-center"
                        style={{ color: macro.color }}
                      >
                        <macro.Icon className="w-6 h-6" strokeWidth={2} />
                      </div>
                    </div>

                    <div className="ln-display text-4xl font-bold leading-none ln-text mt-1">
                      {macro.consumed}
                      <span
                        className="text-base font-normal ml-1 align-baseline"
                        style={{ color: "var(--foreground-muted)" }}
                      >
                        {t("gramUnit")}
                      </span>
                    </div>
                    <div
                      className="text-xs font-semibold mt-3 tracking-wide"
                      style={{ color: macro.color }}
                    >
                      {macro.label}
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>
        </div>
      </div>

      <a
        href="#features"
        aria-label="Scroll to features"
        className="hidden md:flex absolute bottom-8 left-1/2 -translate-x-1/2 items-center justify-center"
      >
        <motion.div
          animate={{ y: [0, 8, 0] }}
          transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
          className="ln-text-subtle"
        >
          <ChevronDown className="w-6 h-6" />
        </motion.div>
      </a>
    </section>
  );
}
