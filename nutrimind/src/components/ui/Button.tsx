"use client";
import { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode, useRef } from "react";
import { motion, useMotionValue, useSpring } from "framer-motion";

type ButtonVariant = "primary" | "secondary" | "dark" | "onBrand";

const variantClass: Record<ButtonVariant, string> = {
  primary: "ln-btn-primary",
  secondary: "ln-btn-secondary",
  dark: "ln-btn-dark",
  onBrand: "ln-btn-on-brand",
};

const baseClass =
  "group inline-flex items-center justify-center gap-2 rounded-full font-semibold transition-all duration-300";

interface CommonProps {
  variant?: ButtonVariant;
  /** Opt-in "magnetic" hover pull toward the cursor. Use sparingly — one or two
   *  flagship CTAs per page, not every button, or the effect stops feeling special. */
  magnetic?: boolean;
  children: ReactNode;
  className?: string;
}

type ButtonAsButton = CommonProps &
  ButtonHTMLAttributes<HTMLButtonElement> & { href?: undefined };

type ButtonAsLink = CommonProps &
  AnchorHTMLAttributes<HTMLAnchorElement> & { href: string };

type ButtonProps = ButtonAsButton | ButtonAsLink;

const MAGNETIC_MAX_PX = 10;
const MAGNETIC_STRENGTH = 0.3;

function useMagnetic() {
  const ref = useRef<HTMLElement>(null);
  const rawX = useMotionValue(0);
  const rawY = useMotionValue(0);
  const x = useSpring(rawX, { stiffness: 300, damping: 20, mass: 0.5 });
  const y = useSpring(rawY, { stiffness: 300, damping: 20, mass: 0.5 });

  const onMouseMove = (e: React.MouseEvent<HTMLElement>) => {
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const relX = e.clientX - (rect.left + rect.width / 2);
    const relY = e.clientY - (rect.top + rect.height / 2);
    rawX.set(Math.max(-MAGNETIC_MAX_PX, Math.min(MAGNETIC_MAX_PX, relX * MAGNETIC_STRENGTH)));
    rawY.set(Math.max(-MAGNETIC_MAX_PX, Math.min(MAGNETIC_MAX_PX, relY * MAGNETIC_STRENGTH)));
  };

  const onMouseLeave = () => {
    rawX.set(0);
    rawY.set(0);
  };

  return { ref, x, y, onMouseMove, onMouseLeave };
}

/**
 * Shared CTA button. Renders an <a> when `href` is passed, otherwise a <button>.
 * All hover/active states live in globals.css (.ln-btn-*), no inline theme JS.
 * Pass `magnetic` to make it pull gently toward the cursor on hover.
 */
export default function Button({
  variant = "primary",
  magnetic = false,
  className = "",
  children,
  ...rest
}: ButtonProps) {
  const classes = `${baseClass} ${variantClass[variant]} px-6 py-3.5 text-sm ${className}`;
  const { ref, x, y, onMouseMove, onMouseLeave } = useMagnetic();

  if ("href" in rest && rest.href) {
    // Framer Motion's HTMLMotionProps redefines onDrag/onAnimation* with different
    // signatures than the standard DOM handlers on AnchorHTMLAttributes, so they're
    // stripped here before spreading onto <motion.a>. None of this codebase's Button
    // call sites pass them (confirmed via repo-wide search).
    /* eslint-disable @typescript-eslint/no-unused-vars */
    const {
      href,
      onDrag,
      onDragStart,
      onDragEnd,
      onAnimationStart,
      onAnimationEnd,
      onAnimationIteration,
      ...anchorRest
    } = rest as ButtonAsLink;
    /* eslint-enable @typescript-eslint/no-unused-vars */

    if (magnetic) {
      return (
        <motion.a
          ref={ref as React.Ref<HTMLAnchorElement>}
          href={href}
          className={classes}
          style={{ x, y }}
          onMouseMove={onMouseMove}
          onMouseLeave={onMouseLeave}
          {...anchorRest}
        >
          {children}
        </motion.a>
      );
    }
    return (
      <a href={href} className={classes} {...anchorRest}>
        {children}
      </a>
    );
  }

  if (magnetic) {
    // See comment above re: Framer Motion vs. DOM handler type conflicts.
    /* eslint-disable @typescript-eslint/no-unused-vars */
    const {
      onDrag,
      onDragStart,
      onDragEnd,
      onAnimationStart,
      onAnimationEnd,
      onAnimationIteration,
      ...buttonRest
    } = rest as ButtonAsButton;
    /* eslint-enable @typescript-eslint/no-unused-vars */

    return (
      <motion.button
        ref={ref as React.Ref<HTMLButtonElement>}
        className={classes}
        style={{ x, y }}
        onMouseMove={onMouseMove}
        onMouseLeave={onMouseLeave}
        {...buttonRest}
      >
        {children}
      </motion.button>
    );
  }

  return (
    <button className={classes} {...(rest as ButtonAsButton)}>
      {children}
    </button>
  );
}
