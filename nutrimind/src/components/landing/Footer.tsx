"use client";
import { Heart } from "lucide-react";

const footerLinks = {
  Product: [
    { name: "Features", href: "#features" },
    { name: "Pricing", href: "#pricing" },
    { name: "AI Recognition", href: "#" },
    { name: "Integrations", href: "#" },
  ],
  Company: [
    { name: "About", href: "#" },
    { name: "Blog", href: "#" },
    { name: "Careers", href: "#" },
    { name: "Contact", href: "#" },
  ],
  Legal: [
    { name: "Privacy Policy", href: "#" },
    { name: "Terms of Service", href: "#" },
    { name: "Cookie Policy", href: "#" },
    { name: "HIPAA", href: "#" },
  ],
};

export default function Footer() {
  return (
    <footer className="w-full bg-[#050505] py-16 border-t border-[#1a1a1a]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
          {/* Logo column */}
          <div className="col-span-2 md:col-span-1">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 rounded-lg bg-[#22c55e] flex items-center justify-center">
                <span className="text-black font-bold text-lg">N</span>
              </div>
              <span className="text-white font-semibold text-lg">NutriMind</span>
            </div>
            <p className="text-gray-600 text-sm">
              Your AI-powered nutrition companion. Eat smart, live better.
            </p>
          </div>

          {/* Link columns */}
          {Object.entries(footerLinks).map(([title, links]) => (
            <div key={title}>
              <h4 className="text-white font-semibold mb-4">{title}</h4>
              <ul className="space-y-3">
                {links.map((link) => (
                  <li key={link.name}>
                    <a
                      href={link.href}
                      className="text-gray-600 hover:text-white text-sm transition-colors duration-300"
                    >
                      {link.name}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 pt-8 border-t border-[#1a1a1a]">
          <p className="text-gray-700 text-sm flex items-center gap-1">
            Made with <Heart className="w-3 h-3 text-[#22c55e]" /> by the NutriMind team
          </p>
          <p className="text-gray-700 text-sm">&copy; 2026 NutriMind. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}