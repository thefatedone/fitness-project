"use client";
import { useEffect, useState, useCallback } from "react";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";
import CalorieRing from "@/components/dashboard/CalorieRing";
import MacroBar from "@/components/dashboard/MacroBar";
import MealCard from "@/components/dashboard/MealCard";
import AddFoodModal from "@/components/dashboard/AddFoodModal";
import WaterTracker from "@/components/dashboard/WaterTracker";

interface DailySummary {
  date: string;
  calories_consumed: number;
  calories_target: number;
  protein_consumed: number;
  protein_target: number;
  carbs_consumed: number;
  carbs_target: number;
  fat_consumed: number;
  fat_target: number;
  water_consumed: number;
  water_target: number;
  meals: {
    breakfast: FoodItem[];
    lunch: FoodItem[];
    dinner: FoodItem[];
    snack: FoodItem[];
  };
}

interface FoodItem {
  id: number;
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  quantity: number;
  unit: string;
}

const mealConfig = [
  { key: "breakfast", label: "Breakfast", emoji: "🍳" },
  { key: "lunch", label: "Lunch", emoji: "🥗" },
  { key: "dinner", label: "Dinner", emoji: "🍽️" },
  { key: "snack", label: "Snack", emoji: "🍎" },
];

export default function TrackerPage() {
  const [dailyData, setDailyData] = useState<DailySummary | null>(null);
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split("T")[0]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedMeal, setSelectedMeal] = useState("");

  const fetchDailyData = useCallback(async () => {
    setIsLoading(true);
    setError("");
    try {
      const token = localStorage.getItem("nutrimind_token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
      const res = await fetch(`${apiUrl}/api/v1/tracker/daily?date=${selectedDate}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setDailyData(data);
      } else if (res.status === 404) {
        setDailyData({
          date: selectedDate,
          calories_consumed: 0,
          calories_target: 2000,
          protein_consumed: 0,
          protein_target: 150,
          carbs_consumed: 0,
          carbs_target: 250,
          fat_consumed: 0,
          fat_target: 65,
          water_consumed: 0,
          water_target: 2000,
          meals: { breakfast: [], lunch: [], dinner: [], snack: [] },
        });
      } else {
        setError("Failed to load data");
      }
    } catch {
      setError("Unable to connect to server");
    } finally {
      setIsLoading(false);
    }
  }, [selectedDate]);

  useEffect(() => {
    fetchDailyData();
  }, [fetchDailyData]);

  const handleAddFood = (mealType: string) => {
    setSelectedMeal(mealType);
    setModalOpen(true);
  };

  const navigateDate = (direction: number) => {
    const date = new Date(selectedDate);
    date.setDate(date.getDate() + direction);
    setSelectedDate(date.toISOString().split("T")[0]);
  };

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left column skeleton */}
          <div className="lg:col-span-2 space-y-6">
            <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 animate-pulse">
              <div className="h-48 bg-[#1a1a1a] rounded-xl" />
            </div>
            <div className="space-y-4">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-16 bg-[#1a1a1a] rounded-xl animate-pulse" />
              ))}
            </div>
          </div>
          {/* Right column skeleton */}
          <div className="space-y-4">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-32 bg-[#1a1a1a] rounded-2xl animate-pulse" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header with date navigation */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Daily Tracker</h1>
        <div className="flex items-center gap-2 bg-[#111111] border border-[#1a1a1a] rounded-xl p-1">
          <button
            onClick={() => navigateDate(-1)}
            className="p-2 text-gray-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <span className="px-4 py-2 text-white font-medium min-w-[140px] text-center">
            {new Date(selectedDate).toLocaleDateString("en-US", {
              weekday: "short",
              month: "short",
              day: "numeric",
            })}
          </span>
          <button
            onClick={() => navigateDate(1)}
            className="p-2 text-gray-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>

      {error && (
        <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400">
          {error}
          <button onClick={fetchDailyData} className="ml-4 underline hover:no-underline">
            Retry
          </button>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column - Calorie Ring, Macros, Water */}
        <div className="lg:col-span-2 space-y-6">
          {/* Calorie Ring Card */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 flex items-center justify-center">
            <CalorieRing
              consumed={dailyData?.calories_consumed || 0}
              target={dailyData?.calories_target || 2000}
            />
          </div>

          {/* Macro Bars */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 space-y-5">
            <h2 className="text-white font-semibold mb-4">Macronutrients</h2>
            <MacroBar
              label="Protein"
              current={dailyData?.protein_consumed || 0}
              target={dailyData?.protein_target || 150}
              color="#3b82f6"
            />
            <MacroBar
              label="Carbohydrates"
              current={dailyData?.carbs_consumed || 0}
              target={dailyData?.carbs_target || 250}
              color="#f97316"
            />
            <MacroBar
              label="Fat"
              current={dailyData?.fat_consumed || 0}
              target={dailyData?.fat_target || 65}
              color="#a855f7"
            />
          </div>

          {/* Water Tracker */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <WaterTracker
              currentAmount={dailyData?.water_consumed || 0}
              onUpdate={fetchDailyData}
            />
          </div>
        </div>

        {/* Right Column - Meal Cards */}
        <div className="space-y-4">
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-white font-semibold">Meals</h2>
          </div>
          {mealConfig.map((meal) => (
            <MealCard
              key={meal.key}
              mealType={meal.label}
              emoji={meal.emoji}
              items={(dailyData?.meals as Record<string, FoodItem[]>) [meal.key] || []}
              onAddFood={handleAddFood}
            />
          ))}
        </div>
      </div>

      {/* Empty State */}
      {!dailyData && !isLoading && (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <span className="text-6xl mb-4">🍎</span>
          <h2 className="text-xl font-semibold text-white mb-2">No meals logged yet</h2>
          <p className="text-gray-500 mb-6">Start tracking your nutrition journey today!</p>
          <button
            onClick={() => handleAddFood("Breakfast")}
            className="flex items-center gap-2 px-6 py-3 bg-[#22c55e] text-black font-semibold rounded-xl hover:bg-[#16a34a] transition-colors"
          >
            <Plus className="w-4 h-4" />
            Add First Meal
          </button>
        </div>
      )}

      {/* Add Food Modal */}
      <AddFoodModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        mealType={selectedMeal}
        onFoodAdded={fetchDailyData}
      />
    </div>
  );
}