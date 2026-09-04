"use client";
import { motion, useScroll } from "framer-motion";

/**
 * Thin fixed bar at the very top of the page showing scroll progress
 * down the document. Sits above the Navbar (z-60 vs Navbar's z-50).
 */
export default function ScrollProgressBar() {
  const { scrollYProgress } = useScroll();

  return (
    <motion.div
      className="fixed top-0 left-0 right-0 h-1 origin-left z-[60] bg-[#22c55e] pointer-events-none"
      style={{ scaleX: scrollYProgress }}
    />
  );
}
