"use client";
import { motion } from "framer-motion";
import { User, ForkKnife, Sparkles } from "lucide-react";

const steps = [
  {
    number: "01",
    icon: User,
    title: "Set Your Profile",
    description: "Tell us your age, weight, goals, and dietary preferences. Our AI calculates your perfect daily targets.",
  },
  {
    number: "02",
    icon: ForkKnife,
    title: "Log Your Meals",
    description: "Snap a photo or search our database. Track every meal with accurate macro breakdowns.",
  },
  {
    number: "03",
    icon: Sparkles,
    title: "Get AI Insights",
    description: "Receive personalized recommendations, meal suggestions, and real-time nutrition coaching.",
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="w-full py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section title */}
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white mb-4">
            How It Works
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto">
            Three simple steps to transform your nutrition journey.
          </p>
        </div>

        {/* Steps */}
        <div className="relative">
          {/* Connecting line (desktop) */}
          <div className="hidden lg:block absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-2/3 h-px bg-gradient-to-r from-transparent via-[#22c55e]/30 to-transparent" />

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 lg:gap-12">
            {steps.map((step, index) => (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: index * 0.2, ease: [0.32, 0.72, 0, 1] }}
                className="relative flex flex-col items-center text-center"
              >
                {/* Step circle */}
                <div className="w-16 h-16 rounded-full bg-[#111111] border border-[#22c55e]/30 flex items-center justify-center mb-6 relative z-10">
                  <step.icon className="w-7 h-7 text-[#22c55e]" strokeWidth={1.5} />
                </div>

                {/* Number */}
                <div className="absolute -top-2 -right-2 w-8 h-8 rounded-full bg-[#22c55e] flex items-center justify-center">
                  <span className="text-black text-xs font-bold">{step.number}</span>
                </div>

                <h3 className="text-xl font-bold text-white mb-3">{step.title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed max-w-xs">{step.description}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}