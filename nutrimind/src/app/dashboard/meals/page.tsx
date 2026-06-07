"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { ChefHat, Sparkles, Plus, Clock, Flame, BrainCircuit, X, Camera } from "lucide-react";
import AddFoodModal from "@/components/dashboard/AddFoodModal";
import PhotoLogModal from "@/components/dashboard/PhotoLogModal";

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
  water_target: number;
  meals: {
    breakfast: FoodItem[];
    lunch: FoodItem[];
    dinner: FoodItem[];
    snack: FoodItem[];
  };
}

interface UserData {
  primary_goal?: string;
  daily_cal_target?: number;
  protein_target?: number;
  carbs_target?: number;
  fat_target?: number;
  tdee?: number;
  bmr?: number;
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
  const [showPhotoModal, setShowPhotoModal] = useState(false);
  const [user, setUser] = useState<UserData | null>(null);

  const token = typeof window !== "undefined" ? localStorage.getItem("nutrimind_token") : null;
  const API = process.env.NEXT_PUBLIC_API_URL;

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
          fetch(`${API}/api/v1/tracker/daily?date_str=${date}`, {
            headers: { Authorization: `Bearer ${token}` },
          }).then((r) => (r.ok ? r.json() : null))
        );
        const results = await Promise.all(promises);

        const dataMap: Record<string, DailyData> = {};
        weekDates.forEach((date, i) => {
          const logs = results[i] || [];
          const mealsMap: { breakfast: FoodItem[]; lunch: FoodItem[]; dinner: FoodItem[]; snack: FoodItem[] } = {
            breakfast: [],
            lunch: [],
            dinner: [],
            snack: [],
          };
          let calories_consumed = 0;
          let protein_consumed = 0;
          let carbs_consumed = 0;
          let fat_consumed = 0;

          for (const log of logs) {
            const mealKey = log.meal_type?.toLowerCase() as keyof typeof mealsMap;
            if (mealKey in mealsMap) {
              mealsMap[mealKey].push({
                id: log.id,
                food_name: log.food_name,
                calories: log.calories,
                protein: log.protein,
                carbs: log.carbs,
                fat: log.fat,
                quantity: log.quantity,
                unit: log.unit,
              });
            }
            calories_consumed += log.calories || 0;
            protein_consumed += log.protein || 0;
            carbs_consumed += log.carbs || 0;
            fat_consumed += log.fat || 0;
          }

          dataMap[date] = {
            date,
            calories_consumed,
            calories_target: 2000,
            protein_consumed,
            protein_target: 150,
            carbs_consumed,
            carbs_target: 250,
            fat_consumed,
            fat_target: 65,
            water_consumed: 0,
            water_target: 2000,
            meals: mealsMap,
          };
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
      const res = await fetch(`${API}/api/v1/tracker/daily?date_str=${selectedDate}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const logs = await res.json();
        const mealsMap: { breakfast: FoodItem[]; lunch: FoodItem[]; dinner: FoodItem[]; snack: FoodItem[] } = {
          breakfast: [],
          lunch: [],
          dinner: [],
          snack: [],
        };
        let calories_consumed = 0;
        let protein_consumed = 0;
        let carbs_consumed = 0;
        let fat_consumed = 0;

        for (const log of logs) {
          const mealKey = log.meal_type?.toLowerCase() as keyof typeof mealsMap;
          if (mealKey in mealsMap) {
            mealsMap[mealKey].push({
              id: log.id,
              food_name: log.food_name,
              calories: log.calories,
              protein: log.protein,
              carbs: log.carbs,
              fat: log.fat,
              quantity: log.quantity,
              unit: log.unit,
            });
          }
          calories_consumed += log.calories || 0;
          protein_consumed += log.protein || 0;
          carbs_consumed += log.carbs || 0;
          fat_consumed += log.fat || 0;
        }

        setWeekData((prev) => ({
          ...prev,
          [selectedDate]: {
            date: selectedDate,
            calories_consumed,
            calories_target: 2000,
            protein_consumed,
            protein_target: 150,
            carbs_consumed,
            carbs_target: 250,
            fat_consumed,
            fat_target: 65,
            water_consumed: 0,
            water_target: 2000,
            meals: mealsMap,
          },
        }));
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

  const generateMealPlan = async (type: "bulk" | "cut") => {
    if (!token) return;
    const dayData = weekData[selectedDate];
    const userData = user;

    // Calculate calories based on type
    const baseTarget = userData?.daily_cal_target || 2000;
    const caloriesForPlan = type === "bulk"
      ? Math.round(baseTarget * 1.15)  // +15% for bulking
      : Math.round(baseTarget * 0.75); // -25% for cutting

    const remaining = caloriesForPlan - (dayData?.calories_consumed || 0);
    const calorieLabel = type === "bulk" ? "surplus" : "deficit";
    const proteinTarget = userData?.protein_target || 150;

    const promptMessage = `Generate a complete ${type === "bulk" ? "muscle building" : "fat loss"} meal plan for ${formatSelectedDate(selectedDate)}.

USER PROFILE:
- Daily calorie target: ${baseTarget} kcal
- For ${type === "bulk" ? "muscle building" : "fat loss"}: ${caloriesForPlan} kcal (${calorieLabel})
- Protein target: ${proteinTarget}g
- Remaining calories today: ${remaining} kcal

REQUIREMENTS:
1. Create a detailed meal plan with breakfast, lunch, dinner, and snacks
2. For each meal include: food name, portion size, calories, protein, carbs, fat
3. Total daily calories should be approximately ${caloriesForPlan} kcal
4. Protein should be around ${proteinTarget}g (${type === "bulk" ? "to support muscle growth" : "to preserve muscle during fat loss"})
5. Make foods delicious and practical for ${type === "bulk" ? "building muscle" : "losing fat"}
6. Suggest specific brands or preparation methods where helpful

Format the response clearly with meal headers and nutritional information.`;

    // Store message in localStorage and navigate to AI assistant
    localStorage.setItem("pending_ai_message", promptMessage);
    window.location.href = "/dashboard/assistant";
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
        <button onClick={() => setShowPhotoModal(true)}
          className="ml-auto flex items-center gap-2 px-5 py-3 bg-green-500 hover:bg-green-600 text-black font-semibold rounded-xl transition-all shadow-lg shadow-green-500/20 hover:-translate-y-0.5">
          <Camera className="w-5 h-5" />
          Log Food by Photo
        </button>
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
                className={`flex-shrink-0 w-20 p-3 rounded-2xl transition-all cursor-pointer ${
                  isSelected
                    ? "bg-green-500/10 border-2 border-green-500"
                    : "bg-[#111111] border border-[#1a1a1a] hover:border-green-500/50"
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
                    className="w-full flex items-center justify-center gap-2 py-2 border border-dashed border-[#2a2a2a] rounded-xl text-gray-400 hover:text-green-400 hover:border-green-500/50 transition-colors text-sm cursor-pointer"
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

            {/* User's Daily Targets */}
            <div className="bg-[#0a0a0a] rounded-xl p-4 mb-4">
              <p className="text-gray-500 text-xs mb-2">Your Daily Targets</p>
              <div className="flex items-center gap-4">
                <div>
                  <p className="text-green-400 text-lg font-bold">{user?.daily_cal_target || 2000}</p>
                  <p className="text-gray-500 text-xs">kcal base</p>
                </div>
                <div className="w-px h-8 bg-[#2a2a2a]" />
                <div>
                  <p className="text-blue-400 text-lg font-bold">{user?.protein_target || 150}g</p>
                  <p className="text-gray-500 text-xs">protein</p>
                </div>
              </div>
            </div>

            {/* Two Generate Buttons */}
            <div className="grid grid-cols-2 gap-3">
              {/* Bulk/Mass Button */}
              <button
                onClick={() => generateMealPlan("bulk")}
                className="py-3 px-4 rounded-xl bg-gradient-to-br from-orange-500 to-red-600 text-white font-semibold hover:from-orange-600 hover:to-red-700 active:scale-[0.98] transition-all flex flex-col items-center gap-1 cursor-pointer"
              >
                <span className="text-lg">💪</span>
                <span className="text-xs">Bulk / Mass</span>
                <span className="text-[10px] opacity-70">+15% calories</span>
              </button>

              {/* Cut/Deficit Button */}
              <button
                onClick={() => generateMealPlan("cut")}
                className="py-3 px-4 rounded-xl bg-gradient-to-br from-cyan-500 to-blue-600 text-white font-semibold hover:from-cyan-600 hover:to-blue-700 active:scale-[0.98] transition-all flex flex-col items-center gap-1 cursor-pointer"
              >
                <span className="text-lg">🔥</span>
                <span className="text-xs">Cut / Deficit</span>
                <span className="text-[10px] opacity-70">-25% calories</span>
              </button>
            </div>

            <p className="text-gray-600 text-xs text-center mt-3">
              Opens AI Assistant with your meal plan
            </p>
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

      {/* Photo Log Modal */}
      <PhotoLogModal
        isOpen={showPhotoModal}
        onClose={() => setShowPhotoModal(false)}
        onSuccess={() => { setShowPhotoModal(false); refreshSelectedDate(); }}
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