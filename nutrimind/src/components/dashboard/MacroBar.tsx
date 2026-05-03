"use client";
import { motion } from "framer-motion";
import { useEffect, useState } from "react";

interface MacroBarProps {
  label: string;
  current: number;
  target: number;
  color: string;
  unit?: string;
}

export default function MacroBar({ label, current, target, color, unit = "g" }: MacroBarProps) {
  const [animatedWidth, setAnimatedWidth] = useState(0);
  const percentage = target > 0 ? Math.min((current / target) * 100, 100) : 0;

  useEffect(() => {
    const timer = setTimeout(() => {
      setAnimatedWidth(percentage);
    }, 100);
    return () => clearTimeout(timer);
  }, [percentage]);

  return (
    <div className="space-y-2">
      <div className="flex justify-between text-sm">
        <span className="text-gray-400 font-medium">{label}</span>
        <span className="text-gray-500">
          {current}{unit} / {target}{unit}
        </span>
      </div>
      <div className="h-2.5 bg-[#1a1a1a] rounded-full overflow-hidden">
        <motion.div
          className="h-full rounded-full"
          style={{ backgroundColor: color, width: `${animatedWidth}%` }}
          initial={{ width: 0 }}
          animate={{ width: `${animatedWidth}%` }}
          transition={{ duration: 0.8, ease: "easeOut" }}
        />
      </div>
    </div>
  );
}