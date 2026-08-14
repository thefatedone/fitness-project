import { HTMLAttributes, ReactNode } from "react";

type CardVariant = "default" | "solid" | "highlighted";

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant;
  hover?: boolean;
  children: ReactNode;
}

const variantClass: Record<CardVariant, string> = {
  default: "ln-card",
  solid: "ln-card-solid",
  highlighted: "ln-card-highlighted",
};

/**
 * Themed card used across Features, HowItWorks, Testimonials, Pricing.
 * `variant="highlighted"` is the solid-brand-green pricing card style.
 */
export default function Card({
  variant = "default",
  hover = false,
  className = "",
  children,
  ...rest
}: CardProps) {
  return (
    <div
      className={`rounded-2xl ${variantClass[variant]} ${hover ? "ln-card-hover" : ""} ${className}`}
      {...rest}
    >
      {children}
    </div>
  );
}
