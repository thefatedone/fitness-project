"use client";
import { useState } from "react";
import { motion } from "framer-motion";

export default function ContactSection() {
  const [submitted, setSubmitted] = useState(false);
  const [formData, setFormData] = useState({
    firstName: "",
    lastName: "",
    email: "",
    phone: "",
    purpose: "",
    message: "",
  });

  const purposes = [
    { value: "Business Inquiry", label: "Business Inquiry" },
    { value: "Partnership", label: "Partnership" },
    { value: "Technical Support", label: "Technical Support" },
    { value: "General Question", label: "General Question" },
    { value: "Other", label: "Other" },
  ];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const API = process.env.NEXT_PUBLIC_API_URL;
    try {
      const res = await fetch(`${API}/api/v1/contact/submit`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          first_name: formData.firstName,
          last_name: formData.lastName,
          email: formData.email,
          phone: formData.phone,
          purpose: formData.purpose,
          message: formData.message,
        }),
      });
      if (res.ok) {
        setSubmitted(true);
      }
    } catch {
      // keep form visible on error
    }
  };

  return (
    <section className="relative py-24 bg-[#050505] border-t border-[#1a1a1a] overflow-hidden">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[400px] bg-[#22c55e] opacity-[0.03] rounded-full blur-[120px]" />
      </div>

      <div className="relative z-10 max-w-4xl mx-auto px-6">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          viewport={{ once: true }}
          className="text-center mb-4"
        >
          <span className="inline-flex items-center gap-2 text-4xl font-bold text-white">
            <span>📩</span>
            <span>Get in Touch</span>
          </span>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          viewport={{ once: true }}
          className="text-gray-400 text-lg text-center mb-12 max-w-xl mx-auto"
        >
          Have a question, partnership idea, or want to integrate NutriMind into your business? We'd love to hear from you.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.4 }}
          viewport={{ once: true }}
          className="bg-[#0d0d0d] border border-[#1a1a1a] rounded-3xl p-8"
        >
          {submitted ? (
            <div className="text-center py-8">
              <p className="text-2xl mb-2">🎉</p>
              <p className="text-green-400 text-lg font-medium">Message sent!</p>
              <p className="text-gray-400 text-sm mt-2">We will get back to you soon.</p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-gray-400 text-sm mb-2 block">First Name</label>
                  <input
                    type="text"
                    required
                    value={formData.firstName}
                    onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                    className="w-full bg-[#111111] border border-[#1a1a1a] text-white rounded-xl px-4 py-3 focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all"
                    placeholder="John"
                  />
                </div>
                <div>
                  <label className="text-gray-400 text-sm mb-2 block">Last Name</label>
                  <input
                    type="text"
                    required
                    value={formData.lastName}
                    onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                    className="w-full bg-[#111111] border border-[#1a1a1a] text-white rounded-xl px-4 py-3 focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all"
                    placeholder="Doe"
                  />
                </div>
              </div>

              <div>
                <label className="text-gray-400 text-sm mb-2 block">Email</label>
                <input
                  type="email"
                  required
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  className="w-full bg-[#111111] border border-[#1a1a1a] text-white rounded-xl px-4 py-3 focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all"
                  placeholder="you@example.com"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-gray-400 text-sm mb-2 block">Phone (optional)</label>
                  <input
                    type="tel"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    className="w-full bg-[#111111] border border-[#1a1a1a] text-white rounded-xl px-4 py-3 focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all"
                    placeholder="+1 234 567 8900"
                  />
                </div>
                <div>
                  <label className="text-gray-400 text-sm mb-2 block">Purpose</label>
                  <select
                    required
                    value={formData.purpose}
                    onChange={(e) => setFormData({ ...formData, purpose: e.target.value })}
                    className="w-full bg-[#111111] border border-[#1a1a1a] text-white rounded-xl px-4 py-3 focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all"
                  >
                    <option value="" disabled>Select purpose</option>
                    {purposes.map((p) => (
                      <option key={p.value} value={p.value}>{p.label}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="text-gray-400 text-sm mb-2 block">Message</label>
                <textarea
                  required
                  rows={4}
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  className="w-full bg-[#111111] border border-[#1a1a1a] text-white rounded-xl px-4 py-3 focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all resize-none"
                  placeholder="Tell us how we can help..."
                />
              </div>

              <button
                type="submit"
                className="w-full bg-[#22c55e] hover:bg-[#16a34a] text-black font-semibold py-4 rounded-xl text-lg transition-all hover:scale-[1.02] hover:shadow-[0_0_20px_rgba(34,197,94,0.15)]"
              >
                Send Message
              </button>
            </form>
          )}
        </motion.div>
      </div>
    </section>
  );
}