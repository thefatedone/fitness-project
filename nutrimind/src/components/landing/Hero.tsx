"use client";
import { useEffect, useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import { ArrowRight, ChevronDown } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";
import Button from "@/components/ui/Button";

const FOOD_IMAGE_DARK = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80";
const FOOD_IMAGE_LIGHT = "/food-light.png";

export default function Hero() {
  const { t } = useTranslations("hero");
  const { theme } = useTheme();
  const sectionRef = useRef<HTMLElement>(null);
  const spotlightRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end start"],
  });
  const parallaxY = useTransform(scrollYProgress, [0, 1], [0, 140]);

  useEffect(() => {
    const section = sectionRef.current;
    const spotlight = spotlightRef.current;
    if (!section || !spotlight) return;

    let frame: number;
    const handleMove = (e: MouseEvent) => {
      const rect = section.getBoundingClientRect();
      const xPct = ((e.clientX - rect.left) / rect.width) * 100;
      const yPct = ((e.clientY - rect.top) / rect.height) * 100;
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        spotlight.style.setProperty("--spot-x", `${xPct}%`);
        spotlight.style.setProperty("--spot-y", `${yPct}%`);
      });
    };

    section.addEventListener("mousemove", handleMove);
    return () => {
      section.removeEventListener("mousemove", handleMove);
      cancelAnimationFrame(frame);
    };
  }, []);

  const stats = [
    { val: "10M+", label: t("mealsTracked") },
    { val: "98%", label: t("aiAccuracy") },
    { val: "50K+", label: t("activeUsers") },
  ];

  return (
    <section ref={sectionRef} className="w-full min-h-[100dvh] flex items-center relative overflow-hidden pt-16 ln-section-tint ln-mesh-bg">
      <div
        ref={spotlightRef}
        aria-hidden="true"
        className="absolute inset-0 pointer-events-none hidden lg:block"
        style={{
          background:
            "radial-gradient(circle 320px at var(--spot-x, 50%) var(--spot-y, 30%), rgba(34,197,94,0.10), transparent 70%)",
        }}
      />
      <style>{`
        @keyframes scan {
          0%   { top: 0%; transform: translateY(0); }
          100% { top: 100%; transform: translateY(-100%); }
        }
      `}</style>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
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

            <h1 className="ln-heading text-5xl md:text-6xl lg:text-7xl 2xl:text-8xl leading-[0.95] tracking-tight mb-6">
              <span className="block">{t("headline1")}</span>
              <span className="block">{t("headline2")}</span>
              <span className="block ln-eyebrow" style={{ textShadow: theme === "dark" ? "0 0 40px rgba(34,197,94,0.4)" : "none" }}>
                {t("headline3")}
              </span>
            </h1>

            <p className="ln-text-muted text-lg max-w-xl mx-auto lg:mx-0 mb-10">
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
                  <div className="ln-text ln-display text-2xl font-bold">{val}</div>
                  <div className="ln-text-muted text-sm">{label}</div>
                </div>
              ))}
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.32, 0.72, 0, 1] }}
            style={{ y: parallaxY }}
            className="flex justify-end relative"
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

            <div className="relative flex items-center translate-x-12" style={{ height: "520px", marginLeft: "64px" }}>
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                className="relative overflow-hidden flex-shrink-0 bg-black border border-[#1a1a1a]"
                style={{
                  width: "360px",
                  height: "520px",
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
                <div className="absolute top-4 left-4 flex items-center gap-2 bg-black/70 backdrop-blur-sm text-green-400 text-xs px-3 py-1.5 rounded-full">
                  <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                  AI Analyzing...
                </div>
                <div className="ln-display absolute bottom-4 left-4 flex items-center gap-1.5 bg-black/80 backdrop-blur-sm border border-white/10 text-white text-sm font-medium px-3 py-1.5 rounded-full">
                  🔥 403 {t("calorieUnit")}
                </div>
                <div className="ln-display absolute bottom-4 right-4 flex items-center gap-1.5 bg-black/80 backdrop-blur-sm border border-white/10 text-white text-sm font-medium px-3 py-1.5 rounded-full">
                  💪 30g {t("protein")}
                </div>
              </motion.div>

              <div style={{ width: "80px", flexShrink: 0 }} />

              <motion.div
                animate={{ y: [0, -14, 0] }}
                transition={{ duration: 4, repeat: Infinity, ease: "easeInOut", delay: 0.5 }}
                className="ln-card-solid relative rounded-3xl p-6 flex-shrink-0 border border-[var(--border)]" style={{ width: "260px", height: "520px" }}>
                {(() => {
                  const today = new Date().toLocaleDateString("en-US", {
                    month: "long",
                    day: "numeric",
                    year: "numeric",
                  });
                  const consumed = 403;
                  const goal = 2000;
                  const percentage = consumed / goal;
                  const radius = 45;
                  const circumference = 2 * Math.PI * radius;
                  const strokeDashoffset = circumference * (1 - percentage);
                  const macros = [
                    { label: t("protein"), consumed: 30, goal: 150, color: "bg-blue-500", percentage: 20 },
                    { label: t("carbs"), consumed: 45, goal: 200, color: "bg-orange-500", percentage: 22 },
                    { label: t("fat"), consumed: 12, goal: 65, color: "bg-purple-500", percentage: 18 },
                  ];
                  return (
                    <>
                      <div className="flex justify-end mb-5">
                        <span className="ln-date-label text-xs font-medium tracking-wide">
                          {today}
                        </span>
                      </div>

                      <div className="flex justify-center mb-6">
                        <svg width="120" height="120" viewBox="0 0 120 120">
                          <circle cx="60" cy="60" r="45" fill="none" stroke="var(--border)" strokeWidth="10" />
                          <circle
                            cx="60"
                            cy="60"
                            r="45"
                            fill="none"
                            stroke="#22c55e"
                            strokeWidth="10"
                            strokeLinecap="round"
                            strokeDasharray={circumference}
                            strokeDashoffset={strokeDashoffset}
                            transform="rotate(-90 60 60)"
                            style={{ transition: "stroke-dashoffset 1s ease" }}
                          />
                          <text x="60" y="55" textAnchor="middle" className="fill-[var(--foreground)]" fontSize="18" fontWeight="bold">
                            {consumed}
                          </text>
                          <text x="60" y="72" textAnchor="middle" className="fill-[var(--foreground-muted)]" fontSize="10">
                            {t("calorieUnit")}
                          </text>
                        </svg>
                      </div>

                      {macros.map((macro) => (
                        <div className="mb-3" key={macro.label}>
                          <div className="flex justify-between mb-1">
                            <span className="ln-text text-xs font-semibold">{macro.label}</span>
                            <span className="ln-text text-xs font-medium">
                              {macro.consumed}g / {macro.goal}g
                            </span>
                          </div>
                          <div className="ln-progress-track w-full h-1.5 rounded-full">
                            <div className={`h-1.5 ${macro.color} rounded-full`} style={{ width: `${macro.percentage}%` }} />
                          </div>
                        </div>
                      ))}
                    </>
                  );
                })()}
              </motion.div>
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
