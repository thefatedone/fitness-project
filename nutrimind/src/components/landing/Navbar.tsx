"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Menu, X } from "lucide-react";

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <nav className="fixed top-0 left-0 right-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <a href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#22c55e] flex items-center justify-center">
              <span className="text-black font-bold text-lg">N</span>
            </div>
            <span className="text-white font-semibold text-lg">NutriMind</span>
          </a>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-8">
            <a href="#features" className="text-gray-400 hover:text-white transition-colors duration-300">Features</a>
            <a href="#pricing" className="text-gray-400 hover:text-white transition-colors duration-300">Pricing</a>
            <a href="/login" className="text-gray-400 hover:text-white transition-colors duration-300">Sign In</a>
            <a
              href="/register"
              className="px-4 py-2 rounded-full bg-[#22c55e] text-black font-medium hover:bg-[#16a34a] active:scale-[0.98] transition-all duration-300"
            >
              Start Free
            </a>
          </div>

          {/* Mobile Hamburger */}
          <button
            className="md:hidden p-2 text-white"
            onClick={() => setIsOpen(!isOpen)}
            aria-label="Toggle menu"
          >
            {isOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </div>

      {/* Mobile Menu */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            transition={{ duration: 0.3, ease: [0.32, 0.72, 0, 1] }}
            className="md:hidden absolute top-16 left-0 right-0 bg-[#0a0a0a]/95 backdrop-blur-xl border-b border-[#1a1a1a]"
          >
            <div className="flex flex-col p-6 gap-4">
              <a href="#features" className="text-gray-400 hover:text-white py-2" onClick={() => setIsOpen(false)}>Features</a>
              <a href="#pricing" className="text-gray-400 hover:text-white py-2" onClick={() => setIsOpen(false)}>Pricing</a>
              <a href="/login" className="text-gray-400 hover:text-white py-2" onClick={() => setIsOpen(false)}>Sign In</a>
              <a
                href="/register"
                className="mt-2 px-4 py-3 rounded-full bg-[#22c55e] text-black font-medium text-center"
                onClick={() => setIsOpen(false)}
              >
                Start Free
              </a>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}