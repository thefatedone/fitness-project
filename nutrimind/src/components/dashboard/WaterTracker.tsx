"use client";
import { useState, useEffect } from "react";
import { Droplet } from "lucide-react";

interface WaterTrackerProps {
  currentAmount: number;
  unitAmount?: number;
  maxGlasses?: number;
  onUpdate: () => void;
}

export default function WaterTracker({
  currentAmount,
  unitAmount = 250,
  maxGlasses = 8,
  onUpdate,
}: WaterTrackerProps) {
  const [glasses, setGlasses] = useState(Math.round(currentAmount / unitAmount));

  useEffect(() => {
    setGlasses(Math.round(currentAmount / unitAmount));
  }, [currentAmount, unitAmount]);

  const toggleGlass = async (index: number) => {
    const newCount = index + 1;
    const newAmount = newCount * unitAmount;

    try {
      const token = localStorage.getItem("nutrimind_token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL ;
      const res = await fetch(`${apiUrl}/api/v1/tracker/water`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ amount: newAmount }),
      });

      if (res.ok) {
        setGlasses(newCount);
        onUpdate();
      }
    } catch (error) {
      console.error("Failed to update water:", error);
    }
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <span className="text-gray-400 text-sm font-medium">Water Intake</span>
        <span className="text-white text-sm">{glasses * unitAmount} ml</span>
      </div>
      <div className="flex gap-2">
        {Array.from({ length: maxGlasses }).map((_, index) => (
          <button
            key={index}
            onClick={() => toggleGlass(index)}
            className={`flex-1 aspect-square rounded-xl flex items-center justify-center transition-all duration-300 ${
              index < glasses
                ? "bg-blue-500 text-white"
                : "bg-[#1a1a1a] text-gray-500 hover:bg-[#2a2a2a]"
            }`}
          >
            <Droplet className={`w-5 h-5 ${index < glasses ? "fill-current" : ""}`} />
          </button>
        ))}
      </div>
      <p className="text-gray-600 text-xs text-center">
        {glasses} of {maxGlasses} glasses ({unitAmount}ml each)
      </p>
    </div>
  );
}