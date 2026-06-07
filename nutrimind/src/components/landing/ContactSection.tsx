"use client";
import { useState } from "react";
import { motion } from "framer-motion";
import { useTranslations } from "@/hooks/useTranslations";

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

  const { t } = useTranslations("contact");

  const purposeOptions = [
    { value: "Business Inquiry", key: "purposeBusiness" },
    { value: "Partnership", key: "purposePartnership" },
    { value: "Technical Support", key: "purposeSupport" },
    { value: "General Question", key: "purposeGeneral" },
    { value: "Other", key: "purposeOther" },
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
    <section
      className="relative py-24 overflow-hidden"
      style={{
        backgroundColor: 'var(--background)',
        borderTopWidth: '1px',
        borderTopStyle: 'solid',
        borderTopColor: 'var(--border)',
      }}
    >
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
          <span
            className="inline-flex items-center gap-2 text-4xl font-bold"
            style={{ color: 'var(--foreground)' }}
          >
            <span>📩</span>
            <span>{t("title")}</span>
          </span>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          viewport={{ once: true }}
          className="text-lg text-center mb-12 max-w-xl mx-auto"
          style={{ color: 'var(--foreground-muted)' }}
        >
          {t("subtitle")}
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.4 }}
          viewport={{ once: true }}
          className="rounded-3xl p-8"
          style={{
            backgroundColor: 'var(--card)',
            borderWidth: '1px',
            borderStyle: 'solid',
            borderColor: 'var(--border)',
          }}
        >
          {submitted ? (
            <div className="text-center py-8">
              <p className="text-2xl mb-2">🎉</p>
              <p className="text-green-400 text-lg font-medium">{t("messageSent")}</p>
              <p className="text-sm mt-2" style={{ color: 'var(--foreground-muted)' }}>{t("weWillGetBack")}</p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label
                    className="text-sm mb-2 block"
                    style={{ color: 'var(--foreground-muted)' }}
                  >
                    {t("firstName")}
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.firstName}
                    onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                    className="w-full rounded-xl px-4 py-3 transition-all"
                    style={{
                      backgroundColor: 'var(--background-secondary)',
                      borderWidth: '1px',
                      borderStyle: 'solid',
                      borderColor: 'var(--border)',
                      color: 'var(--foreground)',
                    }}
                    placeholder={t("placeholderFirstName")}
                  />
                </div>
                <div>
                  <label
                    className="text-sm mb-2 block"
                    style={{ color: 'var(--foreground-muted)' }}
                  >
                    {t("lastName")}
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.lastName}
                    onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                    className="w-full rounded-xl px-4 py-3 transition-all"
                    style={{
                      backgroundColor: 'var(--background-secondary)',
                      borderWidth: '1px',
                      borderStyle: 'solid',
                      borderColor: 'var(--border)',
                      color: 'var(--foreground)',
                    }}
                    placeholder={t("placeholderLastName")}
                  />
                </div>
              </div>

              <div>
                <label
                  className="text-sm mb-2 block"
                  style={{ color: 'var(--foreground-muted)' }}
                >
                  {t("email")}
                </label>
                <input
                  type="email"
                  required
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  className="w-full rounded-xl px-4 py-3 transition-all"
                  style={{
                    backgroundColor: 'var(--background-secondary)',
                    borderWidth: '1px',
                    borderStyle: 'solid',
                    borderColor: 'var(--border)',
                    color: 'var(--foreground)',
                  }}
                  placeholder={t("placeholderEmail")}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label
                    className="text-sm mb-2 block"
                    style={{ color: 'var(--foreground-muted)' }}
                  >
                    {t("phoneOptional")}
                  </label>
                  <input
                    type="tel"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    className="w-full rounded-xl px-4 py-3 transition-all"
                    style={{
                      backgroundColor: 'var(--background-secondary)',
                      borderWidth: '1px',
                      borderStyle: 'solid',
                      borderColor: 'var(--border)',
                      color: 'var(--foreground)',
                    }}
                    placeholder={t("placeholderPhone")}
                  />
                </div>
                <div>
                  <label
                    className="text-sm mb-2 block"
                    style={{ color: 'var(--foreground-muted)' }}
                  >
                    {t("purpose")}
                  </label>
                  <select
                    required
                    value={formData.purpose}
                    onChange={(e) => setFormData({ ...formData, purpose: e.target.value })}
                    className="w-full rounded-xl px-4 py-3 transition-all"
                    style={{
                      backgroundColor: 'var(--background-secondary)',
                      borderWidth: '1px',
                      borderStyle: 'solid',
                      borderColor: 'var(--border)',
                      color: 'var(--foreground)',
                    }}
                  >
                    <option value="" disabled>{t("select")}</option>
                    {purposeOptions.map((p) => (
                      <option key={p.value} value={p.value}>{t(p.key)}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label
                  className="text-sm mb-2 block"
                  style={{ color: 'var(--foreground-muted)' }}
                >
                  {t("message")}
                </label>
                <textarea
                  required
                  rows={4}
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  className="w-full rounded-xl px-4 py-3 transition-all resize-none"
                  style={{
                    backgroundColor: 'var(--background-secondary)',
                    borderWidth: '1px',
                    borderStyle: 'solid',
                    borderColor: 'var(--border)',
                    color: 'var(--foreground)',
                  }}
                  placeholder={t("placeholderMessage")}
                />
              </div>

              <button
                type="submit"
                className="w-full bg-[#22c55e] hover:bg-[#16a34a] text-black font-semibold py-4 rounded-xl text-lg transition-all hover:scale-[1.02] hover:shadow-[0_0_20px_rgba(34,197,94,0.15)]"
              >
                {t("sendMessage")}
              </button>
            </form>
          )}
        </motion.div>
      </div>
    </section>
  );
}
