"use client";
import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";

export default function Hero() {
  return (
    <section className="w-full min-h-[100dvh] flex items-center relative overflow-hidden pt-16">
      {/* Background glow */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-[#22c55e]/10 rounded-full blur-[120px]" />
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Left Content */}
          <motion.div
            initial={{ opacity: 0, x: -40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, ease: [0.32, 0.72, 0, 1] }}
            className="text-center lg:text-left"
          >
            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-[#22c55e]/30 bg-[#22c55e]/5 mb-8">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#22c55e] opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-[#22c55e]" />
              </span>
              <span className="text-[#22c55e] text-sm font-medium">AI-Powered Nutrition</span>
            </div>

            {/* Headline */}
            <h1 className="text-5xl md:text-6xl lg:text-7xl font-black tracking-tight leading-none mb-6">
              <span className="text-white block">Eat Smart.</span>
              <span className="text-white block">Live Better.</span>
              <span className="block bg-gradient-to-r from-[#22c55e] to-[#4ade80] bg-clip-text text-transparent">
                Track Effortlessly.
              </span>
            </h1>

            {/* Subheadline */}
            <p className="text-lg text-gray-500 max-w-xl mx-auto lg:mx-0 mb-10">
              Let AI analyze your meals, calculate macros, and give personalized nutrition advice.
              Your personal dietitian available 24/7.
            </p>

            {/* CTAs */}
            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <a
                href="/register"
                className="group inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-full bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all duration-300"
              >
                Start Free
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </a>
              <a
                href="#how-it-works"
                className="inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-full border border-[#1a1a1a] text-white font-medium hover:border-[#22c55e]/50 hover:bg-[#111111] active:scale-[0.98] transition-all duration-300"
              >
                See How It Works
              </a>
            </div>

            {/* Stats */}
            <div className="flex flex-wrap gap-8 mt-12 justify-center lg:justify-start">
              <div>
                <div className="text-2xl font-bold text-white">10M+</div>
                <div className="text-sm text-gray-600">Meals Tracked</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-white">98%</div>
                <div className="text-sm text-gray-600">AI Accuracy</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-white">50K+</div>
                <div className="text-sm text-gray-600">Active Users</div>
              </div>
            </div>
          </motion.div>

          {/* Right - Dashboard Mockup */}
          <motion.div
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.32, 0.72, 0, 1] }}
            className="flex justify-center lg:justify-end"
          >
            <div className="relative w-full max-w-md">
              {/* Main card */}
              <div className="bg-[#111111] border border-[#1a1a1a] rounded-3xl p-6 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.5)]">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-white font-semibold">Today&apos;s Progress</h3>
                  <span className="text-[#22c55e] text-sm font-medium">May 3, 2026</span>
                </div>

                {/* Calorie ring */}
                <div className="flex items-center gap-6 mb-8">
                  <div className="relative w-24 h-24">
                    <svg className="w-24 h-24 -rotate-90" viewBox="0 0 100 100">
                      <circle cx="50" cy="50" r="42" stroke="#1a1a1a" strokeWidth="8" fill="none" />
                      <circle
                        cx="50" cy="50" r="42"
                        stroke="#22c55e"
                        strokeWidth="8"
                        fill="none"
                        strokeDasharray="264"
                        strokeDashoffset="100"
                        strokeLinecap="round"
                      />
                    </svg>
                    <div className="absolute inset-0 flex flex-col items-center justify-center">
                      <span className="text-xl font-bold text-white">1420</span>
                      <span className="text-xs text-gray-500">/ 2000 kcal</span>
                    </div>
                  </div>

                  <div className="flex-1 space-y-3">
                    <div>
                      <div className="flex justify-between text-sm mb-1">
                        <span className="text-gray-400">Protein</span>
                        <span className="text-white">85g / 150g</span>
                      </div>
                      <div className="h-1.5 bg-[#1a1a1a] rounded-full overflow-hidden">
                        <div className="h-full bg-[#22c55e] rounded-full" style={{ width: "57%" }} />
                      </div>
                    </div>
                    <div>
                      <div className="flex justify-between text-sm mb-1">
                        <span className="text-gray-400">Carbs</span>
                        <span className="text-white">180g / 200g</span>
                      </div>
                      <div className="h-1.5 bg-[#1a1a1a] rounded-full overflow-hidden">
                        <div className="h-full bg-[#4ade80] rounded-full" style={{ width: "90%" }} />
                      </div>
                    </div>
                    <div>
                      <div className="flex justify-between text-sm mb-1">
                        <span className="text-gray-400">Fat</span>
                        <span className="text-white">45g / 65g</span>
                      </div>
                      <div className="h-1.5 bg-[#1a1a1a] rounded-full overflow-hidden">
                        <div className="h-full bg-[#86efac] rounded-full" style={{ width: "69%" }} />
                      </div>
                    </div>
                  </div>
                </div>

                {/* Meal cards */}
                <div className="space-y-3">
                  <div className="flex items-center justify-between p-3 bg-[#0a0a0a] rounded-xl border border-[#1a1a1a]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-[#22c55e]/10 flex items-center justify-center text-sm">🌅</div>
                      <div>
                        <div className="text-white text-sm font-medium">Breakfast</div>
                        <div className="text-xs text-gray-500">2 items</div>
                      </div>
                    </div>
                    <span className="text-[#22c55e] font-semibold">420 kcal</span>
                  </div>
                  <div className="flex items-center justify-between p-3 bg-[#0a0a0a] rounded-xl border border-[#1a1a1a]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-[#22c55e]/10 flex items-center justify-center text-sm">🌞</div>
                      <div>
                        <div className="text-white text-sm font-medium">Lunch</div>
                        <div className="text-xs text-gray-500">1 item</div>
                      </div>
                    </div>
                    <span className="text-[#22c55e] font-semibold">580 kcal</span>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}