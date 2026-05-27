"use client";
import { motion } from "framer-motion";
import { Brain, BarChart3, Target, Utensils, MessageCircle, TrendingUp } from "lucide-react";

const features = [
  { icon: Brain, title: "AI Calorie Recognition", desc: "Snap a photo and let our AI instantly analyze nutritional content." },
  { icon: BarChart3, title: "Smart Daily Tracking", desc: "Log meals effortlessly with real-time macro and calorie calculations." },
  { icon: Target, title: "Personalized Goals", desc: "Custom targets based on your body, activity level, and goals." },
  { icon: Utensils, title: "Meal Planning", desc: "Weekly plans tailored to your preferences and nutrition needs." },
  { icon: MessageCircle, title: "AI Coach 24/7", desc: "Get answers anytime from your personal nutrition assistant." },
  { icon: TrendingUp, title: "Progress Analytics", desc: "Visualize your journey with detailed charts and insights." },
];

export default function Features() {
  return (
    <section id="features" className="w-full py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white mb-4">
            Transform Your <span className="text-[#22c55e]">Health</span>
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto">
            Everything you need to eat better, track smarter, and feel confident about your nutrition.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f, index) => (
            <motion.div
              key={f.title}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className="group p-6 bg-[#111111] border border-[#1a1a1a] rounded-2xl hover:border-[#22c55e]/50 transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_20px_40px_-15px_rgba(34,197,94,0.15)]"
            >
              <div className="w-12 h-12 rounded-xl bg-[#22c55e]/10 flex items-center justify-center mb-4 group-hover:bg-[#22c55e]/20 transition-colors duration-300">
                <f.icon className="w-6 h-6 text-[#22c55e]" strokeWidth={1.5} />
              </div>
              <h3 className="text-lg font-semibold text-white mb-2">{f.title}</h3>
              <p className="text-gray-500 text-sm leading-relaxed">{f.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}