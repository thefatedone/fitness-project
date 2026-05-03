"use client";
import { motion } from "framer-motion";
import { Brain, BarChart3, Target, Utensils, MessageCircle, TrendingUp } from "lucide-react";

const features = [
  {
    icon: Brain,
    title: "AI Calorie Recognition",
    description: "Snap a photo, get instant nutrition data. Our AI identifies foods and estimates calories in seconds.",
  },
  {
    icon: BarChart3,
    title: "Smart Daily Tracking",
    description: "Macro and micronutrient breakdown for every meal. Know exactly what you&apos;re putting in your body.",
  },
  {
    icon: Target,
    title: "Personalized Goals",
    description: "BMI, TDEE, and custom targets based on your body and lifestyle. Science-backed precision.",
  },
  {
    icon: Utensils,
    title: "Meal Planning",
    description: "AI-powered meal suggestions tailored to your taste, goals, and available ingredients.",
  },
  {
    icon: MessageCircle,
    title: "24/7 AI Coach",
    description: "Personal nutrition assistant ready anytime. Ask anything about food, diet, or health.",
  },
  {
    icon: TrendingUp,
    title: "Progress Analytics",
    description: "Beautiful charts and trends that show your journey. Celebrate every milestone.",
  },
];

export default function Features() {
  return (
    <section id="features" className="w-full py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section title */}
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white mb-4">
            Everything You Need to{" "}
            <span className="text-[#22c55e]">Transform</span>
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto">
            Powerful tools designed to make nutrition tracking effortless and effective.
          </p>
        </div>

        {/* Features grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className="group p-6 bg-[#111111] border border-[#1a1a1a] rounded-2xl hover:border-[#22c55e]/50 transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_20px_40px_-15px_rgba(34,197,94,0.15)]"
            >
              <div className="w-12 h-12 rounded-xl bg-[#22c55e]/10 flex items-center justify-center mb-4 group-hover:bg-[#22c55e]/20 transition-colors duration-300">
                <feature.icon className="w-6 h-6 text-[#22c55e]" strokeWidth={1.5} />
              </div>
              <h3 className="text-lg font-semibold text-white mb-2">{feature.title}</h3>
              <p className="text-gray-500 text-sm leading-relaxed" dangerouslySetInnerHTML={{ __html: feature.description }} />
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}