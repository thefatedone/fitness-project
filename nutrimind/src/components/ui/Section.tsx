import { ReactNode } from "react";

type SectionBackground = "default" | "tint" | "alt";

const bgClass: Record<SectionBackground, string> = {
  default: "ln-section",
  tint: "ln-section-tint",
  alt: "ln-section-alt",
};

interface SectionProps {
  id?: string;
  background?: SectionBackground;
  className?: string;
  containerClassName?: string;
  children: ReactNode;
}

/**
 * Standard landing-page section wrapper.
 * Handles background (via CSS token classes, theme-agnostic) + consistent
 * vertical rhythm + centered max-width container.
 */
export default function Section({
  id,
  background = "default",
  className = "",
  containerClassName = "max-w-7xl",
  children,
}: SectionProps) {
  return (
    <section
      id={id}
      className={`w-full py-24 md:py-32 relative ${bgClass[background]} ${className}`}
    >
      <div className={`${containerClassName} mx-auto px-4 sm:px-6 lg:px-8`}>
        {children}
      </div>
    </section>
  );
}
