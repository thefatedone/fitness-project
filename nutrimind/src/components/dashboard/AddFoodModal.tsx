"use client";
import { useState, useEffect, useRef } from "react";
import { X, Search, Plus, Paperclip, Loader2 } from "lucide-react";

interface FoodResult {
  id: number;
  name: string;
  calories_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
}

interface AddFoodModalProps {
  isOpen: boolean;
  onClose: () => void;
  mealType: string;
  onFoodAdded: () => void;
}

export default function AddFoodModal({
  isOpen,
  onClose,
  mealType,
  onFoodAdded,
}: AddFoodModalProps) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<FoodResult[]>([]);
  const [selectedFood, setSelectedFood] = useState<FoodResult | null>(null);
  const [quantity, setQuantity] = useState("100");
  const [unit, setUnit] = useState("g");
  const [manualMode, setManualMode] = useState(false);
  const [manualData, setManualData] = useState({
    name: "",
    calories: "",
    protein: "",
    carbs: "",
    fat: "",
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analyzeError, setAnalyzeError] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  useEffect(() => {
    if (!query.trim() || manualMode) return;

    const searchTimeout = setTimeout(async () => {
      setIsLoading(true);
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
        const token = localStorage.getItem("nutrimind_token");
        const res = await fetch(`${apiUrl}/api/v1/food/search?q=${encodeURIComponent(query)}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          const data = await res.json();
          setResults(data);
        }
      } catch {
        setError("Failed to search foods");
      } finally {
        setIsLoading(false);
      }
    }, 300);

    return () => clearTimeout(searchTimeout);
  }, [query, manualMode]);

  const handleSelectFood = (food: FoodResult) => {
    setSelectedFood(food);
    setQuantity("100");
    setUnit("g");
  };

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (event) => {
      const base64 = event.target?.result as string;
      setSelectedImage(base64);
      await analyzeImage(base64);
    };
    reader.readAsDataURL(file);
  };

  const analyzeImage = async (imageData: string) => {
    const token = localStorage.getItem("nutrimind_token");
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

    setIsAnalyzing(true);
    setAnalyzeError("");
    setManualMode(true);

    try {
      const res = await fetch(`${apiUrl}/api/v1/tracker/analyze-image`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ image: imageData }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.detail || "Failed to analyze image");
      }

      const data = await res.json();
      setManualData({
        name: data.name || "",
        calories: data.calories_per_100g?.toString() || "",
        protein: data.protein_per_100g?.toString() || "",
        carbs: data.carbs_per_100g?.toString() || "",
        fat: data.fat_per_100g?.toString() || "",
      });
    } catch (err) {
      setAnalyzeError(err instanceof Error ? err.message : "Failed to analyze image");
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleRemoveImage = () => {
    setSelectedImage(null);
    setAnalyzeError("");
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleSubmit = async () => {
    const token = localStorage.getItem("nutrimind_token");
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

    try {
      let payload;

      if (selectedFood) {
        const qty = parseFloat(quantity) || 100;
        const multiplier = qty / 100;
        payload = {
          name: selectedFood.name,
          calories: Math.round(selectedFood.calories_per_100g * multiplier),
          protein: Math.round(selectedFood.protein_per_100g * multiplier * 10) / 10,
          carbs: Math.round(selectedFood.carbs_per_100g * multiplier * 10) / 10,
          fat: Math.round(selectedFood.fat_per_100g * multiplier * 10) / 10,
          quantity: qty,
          unit,
          meal_type: mealType.toLowerCase(),
        };
      } else {
        payload = {
          name: manualData.name,
          calories: parseInt(manualData.calories) || 0,
          protein: parseFloat(manualData.protein) || 0,
          carbs: parseFloat(manualData.carbs) || 0,
          fat: parseFloat(manualData.fat) || 0,
          quantity: parseFloat(quantity) || 100,
          unit,
          meal_type: mealType.toLowerCase(),
        };
      }

      const res = await fetch(`${apiUrl}/api/v1/tracker/food`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        onFoodAdded();
        onClose();
      } else {
        const data = await res.json();
        setError(data.detail || "Failed to add food");
      }
    } catch {
      setError("Failed to add food");
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl w-full max-w-md max-h-[80vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-[#1a1a1a]">
          <h2 className="text-white font-semibold">Add to {mealType}</h2>
          <button
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Search */}
        {!selectedFood && (
          <div className="p-4 border-b border-[#1a1a1a]">
            <div className="relative flex gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  ref={inputRef}
                  type="text"
                  placeholder="Search foods..."
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 transition-colors"
                />
              </div>
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className="p-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-400 hover:text-white hover:border-green-500 transition-colors"
                title="Analyze food image"
              >
                <Paperclip className="w-5 h-5" />
              </button>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleImageSelect}
                className="hidden"
              />
            </div>
            {isLoading && (
              <div className="mt-3 flex justify-center">
                <div className="w-5 h-5 border-2 border-green-500/30 border-t-green-500 rounded-full animate-spin" />
              </div>
            )}

            {/* Image Preview */}
            {selectedImage && (
              <div className="mt-3 relative">
                <div className="relative inline-block">
                  <img
                    src={selectedImage}
                    alt="Selected food"
                    className="h-20 w-20 object-cover rounded-lg border border-[#2a2a2a]"
                  />
                  <button
                    type="button"
                    onClick={handleRemoveImage}
                    className="absolute -top-2 -right-2 p-1 bg-red-500 rounded-full text-white hover:bg-red-600"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
                {isAnalyzing && (
                  <div className="mt-2 flex items-center gap-2 text-sm text-gray-400">
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Analyzing image...
                  </div>
                )}
                {analyzeError && (
                  <div className="mt-2 p-2 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-sm">
                    {analyzeError}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          {error && (
            <div className="mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm">
              {error}
            </div>
          )}

          {!selectedFood ? (
            <>
              {/* Search Results */}
              {results.length > 0 ? (
                <div className="space-y-2">
                  {results.map((food) => (
                    <button
                      key={food.id}
                      onClick={() => handleSelectFood(food)}
                      className="w-full text-left p-3 bg-[#1a1a1a] hover:bg-[#2a2a2a] rounded-xl transition-colors"
                    >
                      <p className="text-white font-medium">{food.name}</p>
                      <p className="text-gray-500 text-sm">
                        {food.calories_per_100g} kcal per 100g • P: {food.protein_per_100g}g • C: {food.carbs_per_100g}g • F: {food.fat_per_100g}g
                      </p>
                    </button>
                  ))}
                </div>
              ) : query.length > 1 && !isLoading ? (
                <div className="text-center py-6">
                  <p className="text-gray-500 mb-3">No foods found for "{query}"</p>
                  <button
                    onClick={() => setManualMode(true)}
                    className="text-green-400 hover:underline text-sm"
                  >
                    Add manually
                  </button>
                </div>
              ) : !manualMode ? (
                <p className="text-gray-500 text-center py-6">
                  {query.length === 0 ? "Start typing to search foods..." : ""}
                </p>
              ) : null}

              {/* Manual Entry */}
              {manualMode && (
                <div className="space-y-3">
                  <div>
                    <label className="text-gray-400 text-sm mb-1 block">Food name</label>
                    <input
                      type="text"
                      value={manualData.name}
                      onChange={(e) => setManualData({ ...manualData, name: e.target.value })}
                      className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                      placeholder="e.g., Chicken breast"
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="text-gray-400 text-sm mb-1 block">Calories</label>
                      <input
                        type="number"
                        value={manualData.calories}
                        onChange={(e) => setManualData({ ...manualData, calories: e.target.value })}
                        className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                        placeholder="kcal"
                      />
                    </div>
                    <div>
                      <label className="text-gray-400 text-sm mb-1 block">Quantity</label>
                      <input
                        type="number"
                        value={quantity}
                        onChange={(e) => setQuantity(e.target.value)}
                        className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                      />
                    </div>
                  </div>
                  <div className="grid grid-cols-3 gap-3">
                    <div>
                      <label className="text-gray-400 text-sm mb-1 block">Protein (g)</label>
                      <input
                        type="number"
                        value={manualData.protein}
                        onChange={(e) => setManualData({ ...manualData, protein: e.target.value })}
                        className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                      />
                    </div>
                    <div>
                      <label className="text-gray-400 text-sm mb-1 block">Carbs (g)</label>
                      <input
                        type="number"
                        value={manualData.carbs}
                        onChange={(e) => setManualData({ ...manualData, carbs: e.target.value })}
                        className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                      />
                    </div>
                    <div>
                      <label className="text-gray-400 text-sm mb-1 block">Fat (g)</label>
                      <input
                        type="number"
                        value={manualData.fat}
                        onChange={(e) => setManualData({ ...manualData, fat: e.target.value })}
                        className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                      />
                    </div>
                  </div>
                </div>
              )}
            </>
          ) : (
            /* Selected Food */
            <div className="space-y-4">
              <div className="p-4 bg-[#1a1a1a] rounded-xl">
                <p className="text-white font-semibold mb-2">{selectedFood.name}</p>
                <p className="text-gray-500 text-sm">
                  {selectedFood.calories_per_100g} kcal per 100g
                </p>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-gray-400 text-sm mb-1 block">Quantity</label>
                  <input
                    type="number"
                    value={quantity}
                    onChange={(e) => setQuantity(e.target.value)}
                    className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500"
                  />
                </div>
                <div>
                  <label className="text-gray-400 text-sm mb-1 block">Unit</label>
                  <select
                    value={unit}
                    onChange={(e) => setUnit(e.target.value)}
                    className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500"
                  >
                    <option value="g">g</option>
                    <option value="oz">oz</option>
                    <option value="ml">ml</option>
                    <option value="cup">cup</option>
                    <option value="tbsp">tbsp</option>
                    <option value="piece">piece</option>
                  </select>
                </div>
              </div>
              <button
                onClick={() => setSelectedFood(null)}
                className="text-gray-400 hover:text-white text-sm"
              >
                ← Choose different food
              </button>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-[#1a1a1a]">
          <button
            onClick={handleSubmit}
            disabled={!selectedFood && (!manualMode || !manualData.name)}
            className="w-full py-3.5 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            <Plus className="w-4 h-4" />
            Add to {mealType}
          </button>
        </div>
      </div>
    </div>
  );
}