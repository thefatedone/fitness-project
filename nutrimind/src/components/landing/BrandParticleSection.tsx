"use client";
import ParticleText from "@/components/ui/ParticleText";

/**
 * Closing visual after the "Get in touch" Contact section. The NutriMind
 * brand name is rendered as a ~3.2 px particle field that scatters and
 * re-forms once on mount, then idles with subtle drift and pointer-repel.
 * Uses Comfortaa (the page's brand font) via fontFamily="inherit" so the
 * glyphs sample from the same face used everywhere else.
 */
export default function BrandParticleSection() {
  return (
    <section
      aria-labelledby="brand-particle-heading"
      className="relative w-full overflow-hidden border-t border-[var(--border)]"
    >
      <div className="max-w-[88rem] mx-auto px-4 sm:px-6 lg:px-8 py-16 md:py-24">
        <h2
          id="brand-particle-heading"
          className="sr-only"
        >
          Nutrimind
        </h2>
        <div
          className="relative w-full overflow-hidden rounded-3xl border"
          style={{
            width: "100%",
            height: 400,
            background: "var(--particle-bg)",
            borderColor: "var(--particle-border)",
          }}
        >
          <ParticleText
            text="Nutrimind"
            particleSize={3.2}
            density={4}
            color="#4ADE7F"
            highlightColor="#4ADE7F"
            scatter={180}
            gatherDuration={1500}
            stagger={420}
            pointerRepel={40}
            repelRadius={120}
            idleDrift={0.7}
            trigger="mount"
            fontSize="clamp(3rem, 12vw, 8rem)"
            fontWeight={700}
            fontFamily="inherit"
            glow
          />
        </div>
      </div>
    </section>
  );
}
