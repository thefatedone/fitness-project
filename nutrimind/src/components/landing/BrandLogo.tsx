"use client";
import Link from "next/link";
import { motion } from "framer-motion";

/**
 * Standalone brand mark for the landing page. After the Navbar was removed
 * the logo no longer lives inside a navigation context — it sits in the
 * top-left corner on its own, fades in once on mount, and links back to "/"
 * (so clicking it is a true "go home" action, the same role it had inside
 * the old Navbar). All actual navigation controls now live in the dock at
 * the bottom of the viewport.
 */
export default function BrandLogo() {
  return (
    <motion.div
      initial={{ opacity: 0, y: -8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: [0.32, 0.72, 0, 1] }}
      className="fixed top-5 left-5 sm:top-6 sm:left-6 z-40"
    >
      <Link
        href="/"
        aria-label="NutriMind — go to top"
        className="flex items-center gap-2 select-none"
      >
        <span className="w-10 h-10 rounded-xl bg-[#22c55e] flex items-center justify-center shadow-lg shadow-[#22c55e]/20">
          <span className="text-black font-extrabold text-xl leading-none">
            N
          </span>
        </span>
        <span className="ln-text font-semibold text-xl tracking-tight hidden sm:inline">
          NutriMind
        </span>
      </Link>
    </motion.div>
  );
}
