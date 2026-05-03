"use client";
import { useState } from "react";
import { ChevronDown, Plus } from "lucide-react";

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

interface MealCardProps {
  mealType: string;
  emoji: string;
  items: FoodItem[];
  onAddFood: (mealType: string) => void;
}

export default function MealCard({ mealType, emoji, items, onAddFood }: MealCardProps) {
  const [isExpanded, setIsExpanded] = useState(true);

  const totalCalories = items.reduce((sum, item) => sum + item.calories, 0);

  return (
    <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl overflow-hidden">
      {/* Header */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full flex items-center justify-between p-4 hover:bg-white/5 transition-colors"
      >
        <div className="flex items-center gap-3">
          <span className="text-2xl">{emoji}</span>
          <div className="text-left">
            <h3 className="text-white font-semibold">{mealType}</h3>
            <p className="text-gray-500 text-sm">
              {items.length > 0 ? `${items.length} items` : "No items yet"}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          {items.length > 0 && (
            <span className="text-green-400 font-semibold">{totalCalories} kcal</span>
          )}
          <ChevronDown
            className={`w-5 h-5 text-gray-400 transition-transform ${
              isExpanded ? "rotate-180" : ""
            }`}
          />
        </div>
      </button>

      {/* Expanded Content */}
      {isExpanded && (
        <div className="px-4 pb-4 space-y-2">
          {items.length > 0 ? (
            <div className="space-y-2 pt-2">
              {items.map((item) => (
                <div
                  key={item.id}
                  className="flex items-center justify-between py-2 px-3 bg-[#1a1a1a] rounded-xl"
                >
                  <div className="flex-1">
                    <p className="text-white text-sm font-medium">{item.name}</p>
                    <p className="text-gray-500 text-xs">
                      {item.quantity}{item.unit} • P: {item.protein}g • C: {item.carbs}g • F: {item.fat}g
                    </p>
                  </div>
                  <span className="text-gray-400 text-sm">{item.calories} kcal</span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-sm py-2">No items logged</p>
          )}
          <button
            onClick={() => onAddFood(mealType)}
            className="w-full flex items-center justify-center gap-2 py-2 mt-2 border border-dashed border-[#2a2a2a] rounded-xl text-gray-400 hover:text-green-400 hover:border-green-500/50 transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span className="text-sm">Add food</span>
          </button>
        </div>
      )}
    </div>
  );
}

export type { FoodItem };