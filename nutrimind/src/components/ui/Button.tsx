import { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from "react";

type ButtonVariant = "primary" | "secondary" | "dark" | "onBrand";

const variantClass: Record<ButtonVariant, string> = {
  primary: "ln-btn-primary",
  secondary: "ln-btn-secondary",
  dark: "ln-btn-dark",
  onBrand: "ln-btn-on-brand",
};

const baseClass =
  "inline-flex items-center justify-center gap-2 rounded-full font-semibold transition-all duration-300";

interface CommonProps {
  variant?: ButtonVariant;
  children: ReactNode;
  className?: string;
}

type ButtonAsButton = CommonProps &
  ButtonHTMLAttributes<HTMLButtonElement> & { href?: undefined };

type ButtonAsLink = CommonProps &
  AnchorHTMLAttributes<HTMLAnchorElement> & { href: string };

type ButtonProps = ButtonAsButton | ButtonAsLink;

/**
 * Shared CTA button. Renders an <a> when `href` is passed, otherwise a <button>.
 * All hover/active states live in globals.css (.ln-btn-*), no inline theme JS.
 */
export default function Button({
  variant = "primary",
  className = "",
  children,
  ...rest
}: ButtonProps) {
  const classes = `${baseClass} ${variantClass[variant]} px-6 py-3.5 text-sm ${className}`;

  if ("href" in rest && rest.href) {
    const { href, ...anchorRest } = rest as ButtonAsLink;
    return (
      <a href={href} className={classes} {...anchorRest}>
        {children}
      </a>
    );
  }

  return (
    <button className={classes} {...(rest as ButtonAsButton)}>
      {children}
    </button>
  );
}
