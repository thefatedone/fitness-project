"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { ChefHat, Sparkles, Plus, Clock, Flame, BrainCircuit, X } from "lucide-react";
import AddFoodModal from "@/components/dashboard/AddFoodModal";

interface FoodItem {
  id: string;
  food_name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  quantity: number;
  unit: string;
}

interface DailyData {
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
  meals: {
    breakfast: FoodItem[];
    lunch: FoodItem[];
    dinner: FoodItem[];
    snack: FoodItem[];
  };
}

interface UserData {
  primary_goal?: string;
}

const mealConfig = [
  { key: "breakfast", label: "Breakfast", emoji: "🌅" },
  { key: "lunch", label: "Lunch", emoji: "☀️" },
  { key: "dinner", label: "Dinner", emoji: "🌆" },
  { key: "snack", label: "Snacks", emoji: "🍎" },
];

function getWeekDates(): string[] {
  const today = new Date();
  const dayOfWeek = today.getDay();
  const monday = new Date(today);
  monday.setDate(today.getDate() - ((dayOfWeek + 6) % 7));

  const dates: string[] = [];
  for (let i = 0; i < 7; i++) {
    const date = new Date(monday);
    date.setDate(monday.getDate() + i);
    dates.push(date.toISOString().split("T")[0]);
  }
  return dates;
}

function formatDayName(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString("en-US", { weekday: "short" }).toUpperCase();
}

function formatDateNumber(dateStr: string): string {
  return new Date(dateStr).getDate().toString();
}

function formatSelectedDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
}

function isToday(dateStr: string): boolean {
  const today = new Date().toISOString().split("T")[0];
  return dateStr === today;
}

export default function MealsPage() {
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split("T")[0]);
  const [weekDates, setWeekDates] = useState<string[]>([]);
  const [weekData, setWeekData] = useState<Record<string, DailyData>>({});
  const [isLoadingWeek, setIsLoadingWeek] = useState(true);
  const [aiSuggestion, setAiSuggestion] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [showAddFood, setShowAddFood] = useState(false);
  const [addFoodMealType, setAddFoodMealType] = useState("breakfast");
  const [user, setUser] = useState<UserData | null>(null);

  const token = typeof window !== "undefined" ? localStorage.getItem("nutrimind_token") : null;
  const API = process.env.NEXT_PUBLIC_API_URL ;

  useEffect(() => {
    if (!token) {
      window.location.href = "/login";
      return;
    }
    setWeekDates(getWeekDates());
  }, []);

  useEffect(() => {
    if (!token || weekDates.length === 0) return;

    const fetchData = async () => {
      setIsLoadingWeek(true);
      try {
        const userRes = await fetch(`${API}/api/v1/users/me`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (userRes.ok) {
          setUser(await userRes.json());
        }

        const promises = weekDates.map((date) =>
          fetch(`${API}/api/v1/tracker/daily?date=${date}`, {
            headers: { Authorization: `Bearer ${token}` },
          }).then((r) => (r.ok ? r.json() : null))
        );
        const results = await Promise.all(promises);

        const dataMap: Record<string, DailyData> = {};
        weekDates.forEach((date, i) => {
          dataMap[date] = results[i];
        });
        setWeekData(dataMap);
      } catch (error) {
        console.error("Failed to fetch week data:", error);
      } finally {
        setIsLoadingWeek(false);
      }
    };

    fetchData();
  }, [weekDates, token, API]);

  const refreshSelectedDate = useCallback(async () => {
    if (!token || !selectedDate) return;
    try {
      const res = await fetch(`${API}/api/v1/tracker/daily?date=${selectedDate}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setWeekData((prev) => ({ ...prev, [selectedDate]: data }));
      }
    } catch (error) {
      console.error("Failed to refresh date:", error);
    }
  }, [token, selectedDate, API]);

  const handleAddFood = (mealType: string) => {
    setAddFoodMealType(mealType);
    setShowAddFood(true);
  };

  const deleteFood = async (foodId: string) => {
    try {
      await fetch(`${API}/api/v1/tracker/food/${foodId}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      await refreshSelectedDate();
    } catch (error) {
      console.error("Failed to delete food:", error);
    }
  };

  const getCalorieColor = (consumed: number, target: number): string => {
    if (consumed > target + 100) return "text-red-400";
    if (consumed > target - 100) return "text-yellow-400";
    return "text-green-400";
  };

  const getProgressColor = (consumed: number, target: number): string => {
    if (consumed > target + 100) return "bg-red-500";
    if (consumed > target - 100) return "bg-yellow-500";
    return "bg-green-500";
  };

  const generateMealPlan = async () => {
    if (!token) return;
    const dayData = weekData[selectedDate];
    const remaining = (dayData?.calories_target || 2000) - (dayData?.calories_consumed || 0);

    setIsStreaming(true);
    setAiSuggestion("");

    const userGoal = user?.primary_goal || "maintain";
    const promptMessage = `Generate a complete meal plan for ${formatSelectedDate(selectedDate)}. I have ${remaining} calories remaining today. My goal is ${userGoal}. Include specific foods with portions and calorie counts for each meal.`;

    try {
      const res = await fetch(`${API}/api/v1/ai/chat`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ message: promptMessage }),
      });

      const reader = res.body?.getReader();
      const decoder = new TextDecoder();
      if (!reader) return;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value);
        const lines = chunk.split("\n").filter((l) => l.startsWith("data: "));
        for (const line of lines) {
          const data = line.replace("data: ", "");
          if (data === "[DONE]") break;
          try {
            const { text } = JSON.parse(data);
            setAiSuggestion((prev) => prev + text);
          } catch {}
        }
      }
    } catch (error) {
      console.error("Failed to get AI suggestion:", error);
    } finally {
      setIsStreaming(false);
    }
  };

  const selectedDayData = weekData[selectedDate];
  const remainingCalories = (selectedDayData?.calories_target || 2000) - (selectedDayData?.calories_consumed || 0);

  return (
    <div className="bg-[#0a0a0a] min-h-screen p-6 pb-24">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <div className="w-12 h-12 rounded-xl bg-green-500/20 flex items-center justify-center">
          <ChefHat className="w-6 h-6 text-green-400" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-white">Meal Planner</h1>
          <p className="text-gray-500 text-sm">Plan and track your weekly nutrition</p>
        </div>
      </div>

      {/* Week Strip */}
      <div className="mb-8">
        <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
          {weekDates.map((date) => {
            const dayData = weekData[date];
            const calories = dayData?.calories_consumed || 0;
            const target = dayData?.calories_target || 2000;
            const progress = target > 0 ? Math.min((calories / target) * 100, 100) : 0;
            const isSelected = date === selectedDate;

            return (
              <motion.button
                key={date}
                onClick={() => setSelectedDate(date)}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className={`flex-shrink-0 w-20 p-3 rounded-2xl transition-all ${
                  isSelected
                    ? "bg-green-500/10 border-2 border-green-500"
                    : "bg-[#111111] border border-[#1a1a1a]"
                }`}
              >
                <div className="flex flex-col items-center">
                  <span className="text-gray-500 text-xs font-medium">{formatDayName(date)}</span>
                  <span className="text-white text-xl font-bold mt-1">{formatDateNumber(date)}</span>
                  {isToday(date) && <div className="w-1.5 h-1.5 rounded-full bg-green-500 mt-1" />}

                  {/* Progress Bar */}
                  <div className="w-full h-1.5 bg-[#1a1a1a] rounded-full mt-2 overflow-hidden">
                    <div
                      className={`h-full transition-all ${getProgressColor(calories, target)}`}
                      style={{ width: `${progress}%` }}
                    />
                  </div>
                  <span className="text-gray-500 text-xs mt-1">{calories} kcal</span>
                </div>
              </motion.button>
            );
          })}
        </div>
      </div>

      {/* Selected Day Content */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        {/* Meal Grid */}
        <div className="lg:col-span-2">
          <h2 className="text-white font-semibold mb-4">{formatSelectedDate(selectedDate)}</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {mealConfig.map((meal) => {
              const items = selectedDayData?.meals?.[meal.key as keyof typeof selectedDayData.meals] || [];
              const totalCal = items.reduce((sum, i) => sum + i.calories, 0);

              return (
                <div
                  key={meal.key}
                  className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-4"
                >
                  {/* Header */}
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <span className="text-xl">{meal.emoji}</span>
                      <span className="text-white font-medium">{meal.label}</span>
                    </div>
                    <span className="text-green-400 text-sm font-medium">{totalCal} kcal</span>
                  </div>

                  {/* Food Items */}
                  <div className="space-y-2 mb-3 min-h-[60px]">
                    {items.length > 0 ? (
                      items.map((item) => (
                        <div
                          key={item.id}
                          className="flex items-center justify-between py-2 px-3 bg-[#1a1a1a] rounded-xl"
                        >
                          <div className="flex-1 min-w-0">
                            <p className="text-white text-sm font-medium truncate">{item.food_name}</p>
                            <p className="text-gray-500 text-xs">
                              {item.quantity}{item.unit} · {item.calories} kcal
                            </p>
                          </div>
                          <button
                            onClick={() => deleteFood(item.id)}
                            className="p-1 text-gray-500 hover:text-red-400 transition-colors"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      ))
                    ) : (
                      <p className="text-gray-600 text-sm italic py-4 text-center">No foods logged</p>
                    )}
                  </div>

                  {/* Add Food Button */}
                  <button
                    onClick={() => handleAddFood(meal.key)}
                    className="w-full flex items-center justify-center gap-2 py-2 border border-dashed border-[#2a2a2a] rounded-xl text-gray-400 hover:text-green-400 hover:border-green-500/50 transition-colors text-sm"
                  >
                    <Plus className="w-4 h-4" />
                    Add Food
                  </button>
                </div>
              );
            })}
          </div>
        </div>

        {/* AI Suggestions */}
        <div>
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-4">
              <BrainCircuit className="w-5 h-5 text-green-400" />
              <h3 className="text-white font-semibold">AI Meal Suggestions</h3>
            </div>

            <p className="text-gray-500 text-sm mb-4">
              Remaining: <span className={remainingCalories > 0 ? "text-green-400" : "text-red-400"}>{remainingCalories} kcal</span>
            </p>

            <button
              onClick={generateMealPlan}
              disabled={isStreaming}
              className="w-full py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <Sparkles className="w-4 h-4" />
              {isStreaming ? "Generating..." : "Generate Meal Plan"}
            </button>

            {(aiSuggestion || isStreaming) && (
              <div className="mt-4">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-gray-500 text-xs">AI Suggestion</span>
                  <button
                    onClick={() => setAiSuggestion("")}
                    className="text-gray-500 hover:text-white text-xs"
                  >
                    Clear
                  </button>
                </div>
                <div className="bg-[#0a0a0a] border-l-2 border-green-500 p-4 rounded-r-xl">
                  <pre className="text-gray-300 text-sm whitespace-pre-wrap font-sans">
                    {aiSuggestion}
                    {isStreaming && (
                      <span className="inline-block w-2 h-4 bg-green-400 ml-1 animate-pulse" />
                    )}
                  </pre>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Add Food Modal */}
      <AddFoodModal
        isOpen={showAddFood}
        onClose={() => setShowAddFood(false)}
        mealType={addFoodMealType}
        onFoodAdded={refreshSelectedDate}
      />

      {/* Sticky Summary Bar */}
      <div className="fixed bottom-0 left-0 right-0 bg-[#111111] border-t border-[#1a1a1a] px-6 py-3">
        <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-4">
          <div className="flex flex-wrap items-center gap-6">
            <div className="flex items-center gap-2">
              <Flame className={`w-4 h-4 ${getCalorieColor(selectedDayData?.calories_consumed || 0, selectedDayData?.calories_target || 2000)}`} />
              <span className="text-gray-400 text-sm">Calories</span>
              <span className="text-white font-medium">
                {selectedDayData?.calories_consumed || 0} / {selectedDayData?.calories_target || 2000} kcal
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-blue-400 text-sm">Protein</span>
              <span className="text-white font-medium">{selectedDayData?.protein_consumed || 0}g</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-orange-400 text-sm">Carbs</span>
              <span className="text-white font-medium">{selectedDayData?.carbs_consumed || 0}g</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-purple-400 text-sm">Fat</span>
              <span className="text-white font-medium">{selectedDayData?.fat_consumed || 0}g</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-cyan-400 text-sm">Water</span>
              <span className="text-white font-medium">{selectedDayData?.water_consumed || 0}ml</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}