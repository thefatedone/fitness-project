"use client";
import { motion } from "framer-motion";
import { Check } from "lucide-react";

const plans = [
  {
    name: "Free",
    price: "$0",
    period: "forever",
    description: "Essential tracking for getting started",
    features: [
      "Basic food logging",
      "100 AI messages/month",
      "Daily macro summary",
      "Community support",
    ],
    highlighted: false,
    cta: "Get Started",
  },
  {
    name: "Pro",
    price: "$9.99",
    period: "per month",
    description: "Complete nutrition mastery",
    features: [
      "Unlimited food logging",
      "Unlimited AI messages",
      "Advanced analytics",
      "Meal planning",
      "Priority support",
    ],
    highlighted: true,
    badge: "Most Popular",
    cta: "Start Free Trial",
  },
  {
    name: "Family",
    price: "$19.99",
    period: "per month",
    description: "Share wellness with your household",
    features: [
      "Everything in Pro",
      "Up to 5 family members",
      "Shared meal plans",
      "Family progress dashboard",
      "Dedicated support",
    ],
    highlighted: false,
    cta: "Start Family Plan",
  },
];

export default function Pricing() {
  return (
    <section id="pricing" className="w-full py-24 md:py-32 relative">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section title */}
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white mb-4">
            Simple, Transparent Pricing
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto">
            Start free, upgrade when you&apos;re ready.
          </p>
        </div>

        {/* Pricing cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.1, ease: [0.32, 0.72, 0, 1] }}
              className={`relative p-6 rounded-2xl ${
                plan.highlighted
                  ? "bg-[#111111] border-2 border-[#22c55e] shadow-[0_0_40px_-10px_rgba(34,197,94,0.3)]"
                  : "bg-[#111111] border border-[#1a1a1a]"
              }`}
            >
              {/* Badge */}
              {plan.badge && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-[#22c55e] text-black text-xs font-bold">
                  {plan.badge}
                </div>
              )}

              {/* Plan name */}
              <div className="text-white font-bold text-lg mb-1">{plan.name}</div>

              {/* Price */}
              <div className="flex items-baseline gap-1 mb-2">
                <span className="text-4xl font-black text-white">{plan.price}</span>
                <span className="text-gray-600 text-sm">/{plan.period}</span>
              </div>

              {/* Description */}
              <p className="text-gray-500 text-sm mb-6">{plan.description}</p>

              {/* Features */}
              <ul className="space-y-3 mb-8">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-3">
                    <Check className="w-4 h-4 text-[#22c55e] mt-0.5 flex-shrink-0" strokeWidth={2.5} />
                    <span className="text-gray-400 text-sm">{feature}</span>
                  </li>
                ))}
              </ul>

              {/* CTA */}
              <button
                className={`w-full py-3 rounded-full font-semibold text-sm transition-all duration-300 active:scale-[0.98] ${
                  plan.highlighted
                    ? "bg-[#22c55e] text-black hover:bg-[#16a34a]"
                    : "bg-[#1a1a1a] text-white hover:bg-[#222222]"
                }`}
              >
                {plan.cta}
              </button>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}