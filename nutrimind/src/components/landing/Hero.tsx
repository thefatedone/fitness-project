"use client";
import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";
import { useTranslations } from "@/hooks/useTranslations";
import { useTheme } from "@/context/ThemeContext";

const FOOD_IMAGE_DARK = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80";
const FOOD_IMAGE_LIGHT = "/food-light.png";

export default function Hero() {
  const { t, locale } = useTranslations("hero");
  const { theme } = useTheme();

  return (
    <section
      className="w-full min-h-[100dvh] flex items-center relative overflow-hidden pt-16 transition-colors duration-500 ease-in-out"
      style={{
        backgroundColor: theme === 'light' ? '#f0fdf4' : 'var(--background)',
      }}
    >
      <style>{`
        @keyframes scan {
          0%   { top: 0%; transform: translateY(0); }
          100% { top: 100%; transform: translateY(-100%); }
        }
      `}</style>

      <div className="absolute inset-0 pointer-events-none">
        <div
          style={{
            display: theme === 'dark' ? 'block' : 'none',
            position: 'absolute',
            top: '25%',
            left: '25%',
            width: '24rem',
            height: '24rem',
            background: 'radial-gradient(ellipse at 20% 50%, rgba(34,197,94,0.08) 0%, transparent 60%)',
            borderRadius: '9999px',
            filter: 'blur(120px)',
          }}
        />
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">

          <motion.div
            initial={{ opacity: 0, x: -40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, ease: [0.32, 0.72, 0, 1] }}
            className="text-center lg:text-left"
          >
            <div
              className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border mb-8"
              style={{
                backgroundColor: theme === 'dark' ? 'rgba(34,197,94,0.1)' : '#f0fdf4',
                borderColor: theme === 'dark' ? 'rgba(34,197,94,0.2)' : '#bbf7d0',
              }}
            >
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#22c55e] opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-[#22c55e]" />
              </span>
              <span
                className="text-sm font-medium"
                style={{ color: theme === 'dark' ? '#4ade80' : '#16a34a' }}
              >
                {t("badge")}
              </span>
            </div>

            <h1 className="text-5xl md:text-6xl lg:text-7xl font-black tracking-tight leading-tight mb-6 transition-colors duration-500 ease-in-out">
              <span
                className="block"
                style={{ color: theme === 'dark' ? '#ffffff' : '#0f172a' }}
              >
                {locale === 'ka' ? 'იკვებე სწორად.' : 'Eat Smart.'}
              </span>
              <span
                className="block"
                style={{ color: theme === 'dark' ? '#ffffff' : '#0f172a' }}
              >
                {locale === 'ka' ? 'იცხოვრე უკეთ.' : 'Live Better.'}
              </span>
              <span
                className="block"
                style={{
                  color: theme === 'dark' ? '#4ade80' : '#16a34a',
                  textShadow: theme === 'dark' ? '0 0 40px rgba(34,197,94,0.4)' : 'none',
                }}
              >
                {locale === 'ka' ? 'აკონტროლე მარტივად.' : 'Track Effortlessly.'}
              </span>
            </h1>

            <p
              className="text-lg max-w-xl mx-auto lg:mx-0 mb-10 transition-colors duration-500 ease-in-out"
              style={{ color: theme === 'dark' ? '#6b6b6b' : '#64748b' }}
            >
              {t("subtitle")}
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <a
                href="/register"
                className="group inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-full bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all duration-300"
              >
                {t("cta")} <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </a>
              <a
                href="#how-it-works"
                className="hero-secondary inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-full font-medium active:scale-[0.98] transition-all duration-300"
                style={{ borderWidth: "1px", borderStyle: "solid", borderColor: 'var(--border)', color: 'var(--foreground)' }}
              >
                {t("ctaSecondary")}
              </a>
            </div>

            <div className="flex flex-wrap gap-8 mt-12 justify-center lg:justify-start">
              {[
                { val: "10M+", label: t("mealsTracked") },
                { val: "98%",  label: t("aiAccuracy") },
                { val: "50K+", label: t("activeUsers") },
              ].map(({ val, label }) => (
                <div key={label}>
                  <div className="text-2xl font-bold transition-colors duration-500 ease-in-out" style={{ color: theme === 'dark' ? '#ffffff' : '#0f172a' }}>{val}</div>
                  <div className="text-sm transition-colors duration-500 ease-in-out" style={{ color: theme === 'dark' ? '#525252' : '#64748b' }}>{label}</div>
                </div>
              ))}
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.32, 0.72, 0, 1] }}
            className="flex justify-end"
          >
            <div
              className="relative flex items-center translate-x-12"
              style={{ height: "520px", marginLeft: "64px" }}
            >
              <div
                className="relative overflow-hidden flex-shrink-0 bg-black transition-colors duration-500 ease-in-out"
                style={{
                  width: "360px",
                  height: "520px",
                  borderRadius: "1.5rem",
                  boxShadow: 'inset 0 0 80px 24px rgba(0,0,0,0.9), inset 0 0 160px 48px rgba(0,0,0,0.5)',
                  borderWidth: '1px',
                  borderStyle: 'solid',
                  borderColor: '#1a1a1a',
                }}
              >
                <img
                  src={theme === 'dark' ? FOOD_IMAGE_DARK : FOOD_IMAGE_LIGHT}
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
                <div className="absolute bottom-4 left-4 flex items-center gap-1.5 bg-black/80 backdrop-blur-sm border border-white/10 text-white text-sm font-medium px-3 py-1.5 rounded-full">
                  🔥 403 kcal
                </div>
                <div className="absolute bottom-4 right-4 flex items-center gap-1.5 bg-black/80 backdrop-blur-sm border border-white/10 text-white text-sm font-medium px-3 py-1.5 rounded-full">
                  💪 30g protein
                </div>
              </div>

              <div style={{ width: "80px", flexShrink: 0 }} />

              <div
                className="relative rounded-3xl p-6 flex-shrink-0 transition-colors duration-500 ease-in-out"
                style={{
                  width: "260px",
                  height: "520px",
                  backgroundColor: theme === 'light' ? '#ffffff' : 'var(--card)',
                  borderWidth: '1px',
                  borderStyle: 'solid',
                  borderColor: theme === 'light' ? '#e2e8f0' : 'var(--border)',
                  boxShadow: theme === 'dark'
                    ? '0 25px 80px -20px rgba(0,0,0,0.5), 0 0 40px rgba(34,197,94,0.05)'
                    : '0 8px 32px -8px rgba(0,0,0,0.15), 0 2px 8px rgba(0,0,0,0.08)',
                }}
              >
                {(() => {
                  const today = new Date().toLocaleDateString('en-US', {
                    month: 'long',
                    day: 'numeric',
                    year: 'numeric'
                  });
                  const consumed = 403;
                  const goal = 2000;
                  const percentage = consumed / goal;
                  const radius = 45;
                  const circumference = 2 * Math.PI * radius;
                  const strokeDashoffset = circumference * (1 - percentage);
                  const macros = [
                    { label: locale === 'ka' ? 'ცილები' : 'Protein', consumed: 30, goal: 150, color: 'bg-blue-500', percentage: 20 },
                    { label: locale === 'ka' ? 'ნახშირწყლები' : 'Carbs', consumed: 45, goal: 200, color: 'bg-orange-500', percentage: 22 },
                    { label: locale === 'ka' ? 'ცხიმები' : 'Fat', consumed: 12, goal: 65, color: 'bg-purple-500', percentage: 18 },
                  ];
                  return (
                    <>
                      <div className="flex justify-end mb-5">
                        <span className="text-xs font-medium tracking-wide transition-colors duration-500 ease-in-out text-gray-600 dark:text-[#4ade80]">
                          {today}
                        </span>
                      </div>

                      <div className="flex justify-center mb-6">
                        <svg width="120" height="120" viewBox="0 0 120 120">
                          <circle cx="60" cy="60" r="45" fill="none" stroke={theme === 'dark' ? '#1a1a1a' : '#000000'} strokeWidth="10" />
                          <circle
                            cx="60" cy="60" r="45" fill="none" stroke="#22c55e" strokeWidth="10" strokeLinecap="round"
                            strokeDasharray={circumference} strokeDashoffset={strokeDashoffset}
                            transform="rotate(-90 60 60)"
                            style={{ transition: 'stroke-dashoffset 1s ease' }}
                          />
                          <text x="60" y="55" textAnchor="middle" style={{ fill: theme === 'dark' ? '#ffffff' : '#111827' }} fontSize="18" fontWeight="bold">{consumed}</text>
                          <text x="60" y="72" textAnchor="middle" style={{ fill: theme === 'dark' ? '#9ca3af' : '#6b7280' }} fontSize="10">kcal</text>
                        </svg>
                      </div>

                      {macros.map((macro) => (
                        <div className="mb-3" key={macro.label}>
                          <div className="flex justify-between mb-1">
                            <span className="text-xs font-semibold" style={{ color: theme === 'dark' ? '#ffffff' : '#000000' }}>{macro.label}</span>
                            <span className="text-xs font-medium" style={{ color: theme === 'dark' ? '#ffffff' : '#000000' }}>{macro.consumed}g / {macro.goal}g</span>
                          </div>
                          <div className="w-full h-1.5 rounded-full bg-gray-200 dark:bg-gray-800">
                            <div className={`h-1.5 ${macro.color} rounded-full`} style={{ width: `${macro.percentage}%` }} />
                          </div>
                        </div>
                      ))}
                    </>
                  );
                })()}
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}