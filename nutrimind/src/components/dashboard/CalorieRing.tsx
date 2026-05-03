"use client";
import { motion } from "framer-motion";
import { useEffect, useState } from "react";

interface CalorieRingProps {
  consumed: number;
  target: number;
}

export default function CalorieRing({ consumed, target }: CalorieRingProps) {
  const [animatedProgress, setAnimatedProgress] = useState(0);

  const radius = 80;
  const strokeWidth = 12;
  const circumference = 2 * Math.PI * radius;
  const progress = target > 0 ? Math.min((consumed / target) * 100, 100) : 0;

  useEffect(() => {
    const timer = setTimeout(() => {
      setAnimatedProgress(progress);
    }, 100);
    return () => clearTimeout(timer);
  }, [progress]);

  const strokeDashoffset = circumference - (animatedProgress / 100) * circumference;

  const getColor = () => {
    if (progress >= 100) return "#ef4444";
    if (progress >= 75) return "#eab308";
    return "#22c55e";
  };

  return (
    <div className="relative flex items-center justify-center">
      <svg width="200" height="200" className="transform -rotate-90">
        {/* Background ring */}
        <circle
          cx="100"
          cy="100"
          r={radius}
          fill="none"
          stroke="#1a1a1a"
          strokeWidth={strokeWidth}
        />
        {/* Progress ring */}
        <motion.circle
          cx="100"
          cy="100"
          r={radius}
          fill="none"
          stroke={getColor()}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset }}
          transition={{ duration: 1, ease: "easeOut" }}
        />
      </svg>
      {/* Center text */}
      <div className="absolute flex flex-col items-center">
        <span className="text-3xl font-bold text-white">{consumed}</span>
        <span className="text-gray-500 text-sm">of {target} kcal</span>
      </div>
    </div>
  );
}