"use client";
import { motion } from "framer-motion";
import { Star } from "lucide-react";

const testimonials = [
  {
    name: "Priya Sharma",
    role: "Software Engineer, Bangalore",
    quote: "NutriMind changed how I approach food. The AI recognition is incredibly accurate and the daily tracking keeps me accountable.",
    image: "https://picsum.photos/seed/priya/200/200",
  },
  {
    name: "Marcus Thompson",
    role: "Personal Trainer, Miami",
    quote: "I recommend NutriMind to all my clients. The macro calculations are spot-on and the AI coach gives practical advice they actually follow.",
    image: "https://picsum.photos/seed/marcus/200/200",
  },
  {
    name: "Sofia Rodriguez",
    role: "Nutritionist, Madrid",
    quote: "Finally an app that takes nutrition seriously. The personalized goals and meal planning features are genuinely useful in my practice.",
    image: "https://picsum.photos/seed/sofia/200/200",
  },
];

export default function Testimonials() {
  return (
    <section className="w-full py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white mb-4">What Users Say</h2>
          <p className="text-gray-500 max-w-2xl mx-auto">Join thousands who have transformed their nutrition with NutriMind.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {testimonials.map((t, index) => (
            <motion.div
              key={t.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className="p-6 bg-[#111111] border border-[#1a1a1a] rounded-2xl hover:border-[#22c55e]/30 transition-all duration-300"
            >
              <div className="flex gap-1 mb-4">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} className="w-4 h-4 fill-[#22c55e] text-[#22c55e]" strokeWidth={0} />
                ))}
              </div>
              <p className="text-gray-400 text-sm leading-relaxed mb-6 italic">&ldquo;{t.quote}&rdquo;</p>
              <div className="flex items-center gap-3">
                <img src={t.image} alt={t.name} className="w-10 h-10 rounded-full object-cover" />
                <div>
                  <div className="text-white text-sm font-semibold">{t.name}</div>
                  <div className="text-gray-600 text-xs">{t.role}</div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}