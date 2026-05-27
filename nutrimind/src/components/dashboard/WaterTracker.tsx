"use client";
import { useState, useEffect } from "react";
import { Droplet, Plus, X } from "lucide-react";

interface WaterTrackerProps {
  currentAmount: number;
  onUpdate: () => void;
}

const WATER_AMOUNTS = [
  { label: "250ml", value: 250 },
  { label: "500ml", value: 500 },
  { label: "750ml", value: 750 },
  { label: "1L", value: 1000 },
  { label: "1.5L", value: 1500 },
  { label: "2L", value: 2000 },
  { label: "2.5L", value: 2500 },
  { label: "3L", value: 3000 },
];

export default function WaterTracker({ currentAmount, onUpdate }: WaterTrackerProps) {
  const [glasses, setGlasses] = useState(Math.round(currentAmount / 250));
  const [showModal, setShowModal] = useState(false);
  const [userWeight, setUserWeight] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    setGlasses(Math.round(currentAmount / 250));
  }, [currentAmount]);

  // Fetch user weight for daily goal calculation
  useEffect(() => {
    const fetchUserWeight = async () => {
      const token = localStorage.getItem("nutrimind_token");
      if (!token) return;

      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        const res = await fetch(`${apiUrl}/api/v1/users/me`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          const data = await res.json();
          if (data.current_weight) {
            setUserWeight(data.current_weight);
          }
        }
      } catch {
        // silently fail
      }
    };

    fetchUserWeight();
  }, []);

  const dailyGoal = userWeight ? Math.round(userWeight * 35) : 2000; // ~35ml per kg, default 2L
  const progress = Math.min((currentAmount / dailyGoal) * 100, 100);
  const remaining = Math.max(dailyGoal - currentAmount, 0);

  const addWater = async (amount: number) => {
    setIsLoading(true);
    try {
      const token = localStorage.getItem("nutrimind_token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      const dateStr = new Date().toISOString().split("T")[0];

      const res = await fetch(`${apiUrl}/api/v1/tracker/water`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ amount, date: dateStr }),
      });

      if (res.ok) {
        setShowModal(false);
        onUpdate();
      }
    } catch (error) {
      console.error("Failed to add water:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-gray-400 text-sm font-medium">Water Intake</span>
          <div className="flex items-center gap-2">
            <span className="text-white text-sm font-medium">{currentAmount} ml</span>
            <span className="text-gray-500 text-xs">/ {dailyGoal} ml</span>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="h-2 bg-[#1a1a1a] rounded-full overflow-hidden">
          <div
            className="h-full bg-blue-500 rounded-full transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>

        <div className="flex items-center justify-between">
          <span className="text-gray-500 text-xs">{Math.round(progress)}% of daily goal</span>
          <span className="text-gray-500 text-xs">{remaining} ml remaining</span>
        </div>

        {/* Quick Add Buttons */}
        <div className="flex gap-2 flex-wrap">
          {[250, 500, 750, 1000].map((amount) => (
            <button
              key={amount}
              onClick={() => addWater(amount)}
              disabled={isLoading}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-500/10 hover:bg-blue-500/20 border border-blue-500/30 rounded-lg text-blue-400 text-xs font-medium transition-colors disabled:opacity-50"
            >
              <Plus className="w-3 h-3" />
              {amount >= 1000 ? `${amount / 1000}L` : `${amount}ml`}
            </button>
          ))}
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-[#1a1a1a] hover:bg-[#2a2a2a] border border-[#2a2a2a] rounded-lg text-gray-400 text-xs font-medium transition-colors"
          >
            More
          </button>
        </div>
      </div>

      {/* Add Water Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">Add Water</h3>
              <button
                onClick={() => setShowModal(false)}
                className="p-2 text-gray-400 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-gray-500 text-sm mb-4">Select amount to add:</p>

            <div className="grid grid-cols-2 gap-3">
              {WATER_AMOUNTS.map((item) => (
                <button
                  key={item.value}
                  onClick={() => addWater(item.value)}
                  disabled={isLoading}
                  className="flex items-center justify-center gap-2 py-3 bg-[#1a1a1a] hover:bg-[#2a2a2a] border border-[#2a2a2a] rounded-xl text-white font-medium transition-colors disabled:opacity-50"
                >
                  <Droplet className="w-4 h-4 text-blue-400" />
                  {item.label}
                </button>
              ))}
            </div>

            {userWeight && (
              <p className="text-gray-600 text-xs text-center mt-4">
                Daily goal based on {userWeight}kg weight (~35ml/kg)
              </p>
            )}
          </div>
        </div>
      )}
    </>
  );
}