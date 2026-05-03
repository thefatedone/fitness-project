"use client";
import { motion } from "framer-motion";
import { Star } from "lucide-react";

const testimonials = [
  {
    name: "Priya Krishnamurthy",
    role: "Software Engineer at Stripe",
    image: "https://picsum.photos/seed/priya/200/200",
    quote: "NutriMind changed how I think about food. The AI recognition is incredible — I just snap a photo and it logs everything. Down 18lbs in 3 months.",
    rating: 5,
  },
  {
    name: "Marcus Chen",
    role: "Personal Trainer",
    image: "https://picsum.photos/seed/marcus/200/200",
    quote: "I recommend NutriMind to all my clients. The macro tracking is precise, and the AI coach gives practical advice that actually fits busy lifestyles.",
    rating: 5,
  },
  {
    name: "Sofia Andersson",
    role: "Marketing Director",
    image: "https://picsum.photos/seed/sofia/200/200",
    quote: "Finally an app that makes nutrition tracking effortless. The meal suggestions are creative but realistic. My energy levels have never been better.",
    rating: 5,
  },
];

export default function Testimonials() {
  return (
    <section className="w-full py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section title */}
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white mb-4">
            Loved by Thousands
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto">
            Join the community that&apos;s already transforming their health.
          </p>
        </div>

        {/* Testimonial cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {testimonials.map((testimonial, index) => (
            <motion.div
              key={testimonial.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className="p-6 bg-[#111111] border border-[#1a1a1a] rounded-2xl hover:border-[#22c55e]/30 transition-all duration-300"
            >
              {/* Stars */}
              <div className="flex gap-1 mb-4">
                {[...Array(testimonial.rating)].map((_, i) => (
                  <Star key={i} className="w-4 h-4 fill-[#22c55e] text-[#22c55e]" strokeWidth={0} />
                ))}
              </div>

              {/* Quote */}
              <p className="text-gray-400 text-sm leading-relaxed mb-6 italic">&ldquo;{testimonial.quote}&rdquo;</p>

              {/* Author */}
              <div className="flex items-center gap-3">
                <img
                  src={testimonial.image}
                  alt={testimonial.name}
                  className="w-10 h-10 rounded-full object-cover"
                />
                <div>
                  <div className="text-white text-sm font-semibold">{testimonial.name}</div>
                  <div className="text-gray-600 text-xs">{testimonial.role}</div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}