"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  User,
  Mail,
  Calendar,
  Ruler,
  Weight,
  Target,
  Flame,
  Beef,
  Wheat,
  Droplet,
  Camera,
  Save,
  TrendingUp,
  Clock,
  Award,
} from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { motion } from "framer-motion";

interface UserProfile {
  id: number;
  email?: string;
  phone?: string;
  full_name?: string;
  date_of_birth?: string;
  sex?: string;
  height?: number;
  current_weight?: number;
  target_weight?: number;
  activity_level?: string;
  primary_goal?: string;
  dietary_preferences?: string[];
  food_allergies?: string[];
  daily_cal_target?: number;
  protein_target?: number;
  carbs_target?: number;
  fat_target?: number;
  bmr?: number;
  tdee?: number;
  created_at?: string;
}

interface WeightEntry {
  date: string;
  weight: number;
}

const DIETARY_OPTIONS = [
  "None", "Vegetarian", "Vegan", "Keto", "Paleo",
  "Low-Carb", "Low-Fat", "Mediterranean", "Dash", "Halal", "Kosher"
];

const ALLERGY_OPTIONS = [
  "None", "Peanuts", "Tree Nuts", "Milk", "Eggs",
  "Wheat", "Soy", "Fish", "Shellfish", "Sesame"
];

const ACTIVITY_LEVELS = [
  { value: "sedentary", label: "Sedentary" },
  { value: "lightly_active", label: "Lightly Active" },
  { value: "moderately_active", label: "Moderately Active" },
  { value: "very_active", label: "Very Active" },
  { value: "extra_active", label: "Extra Active" },
];

const GOALS = [
  { value: "lose_weight", label: "Lose Weight", emoji: "🔥" },
  { value: "maintain", label: "Maintain", emoji: "⚖️" },
  { value: "gain_muscle", label: "Gain Muscle", emoji: "💪" },
  { value: "eat_healthier", label: "Eat Healthier", emoji: "🥗" },
];

function calculateBMI(weight: number, height: number): number {
  if (!weight || !height) return 0;
  const h = height / 100;
  return weight / (h * h);
}

function getBMICategory(bmi: number): { label: string; color: string } {
  if (bmi < 18.5) return { label: "Underweight", color: "text-blue-400" };
  if (bmi < 25) return { label: "Normal ✓", color: "text-green-400" };
  if (bmi < 30) return { label: "Overweight", color: "text-yellow-400" };
  return { label: "Obese", color: "text-red-400" };
}

export default function ProfilePage() {
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [weightHistory, setWeightHistory] = useState<WeightEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);

  // Form states
  const [fullName, setFullName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [sex, setSex] = useState("");
  const [height, setHeight] = useState("");
  const [currentWeight, setCurrentWeight] = useState("");
  const [targetWeight, setTargetWeight] = useState("");
  const [activityLevel, setActivityLevel] = useState("");
  const [goalPace, setGoalPace] = useState("0.5");
  const [primaryGoal, setPrimaryGoal] = useState("");
  const [dietaryPrefs, setDietaryPrefs] = useState<string[]>([]);
  const [allergies, setAllergies] = useState<string[]>([]);

  // Weight log form
  const [logDate, setLogDate] = useState(new Date().toISOString().split("T")[0]);
  const [logWeight, setLogWeight] = useState("");

  const token = typeof window !== "undefined" ? localStorage.getItem("nutrimind_token") : null;
  const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

  useEffect(() => {
    if (!token) {
      router.push("/login");
      return;
    }
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [userRes, weightRes] = await Promise.all([
        fetch(`${API}/api/v1/users/me`, { headers: { Authorization: `Bearer ${token}` } }),
        fetch(`${API}/api/v1/tracker/weight/history`, { headers: { Authorization: `Bearer ${token}` } }),
      ]);

      if (userRes.ok) {
        const data = await userRes.json();
        setProfile(data);
        setFullName(data.full_name || "");
        setDateOfBirth(data.date_of_birth || "");
        setSex(data.sex || "");
        setHeight(data.height?.toString() || "");
        setCurrentWeight(data.current_weight?.toString() || "");
        setTargetWeight(data.target_weight?.toString() || "");
        setActivityLevel(data.activity_level || "moderately_active");
        setPrimaryGoal(data.primary_goal || "maintain");
        setDietaryPrefs(data.dietary_preferences || []);
        setAllergies(data.food_allergies || []);
      }

      if (weightRes.ok) {
        const weightData = await weightRes.json();
        setWeightHistory(weightData);
      }
    } catch (error) {
      console.error("Failed to fetch profile:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const showToast = (message: string, type: "success" | "error") => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  const saveProfile = async () => {
    setIsSaving(true);
    try {
      const res = await fetch(`${API}/api/v1/users/me`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          full_name: fullName,
          date_of_birth: dateOfBirth,
          sex,
          height: parseFloat(height) || null,
          current_weight: parseFloat(currentWeight) || null,
          target_weight: parseFloat(targetWeight) || null,
          activity_level: activityLevel,
          primary_goal: primaryGoal,
          dietary_preferences: dietaryPrefs,
          food_allergies: allergies,
        }),
      });

      if (res.ok) {
        showToast("Profile updated successfully!", "success");
        fetchData();
      } else {
        showToast("Failed to update profile", "error");
      }
    } catch {
      showToast("Failed to update profile", "error");
    } finally {
      setIsSaving(false);
    }
  };

  const saveMeasurements = async () => {
    setIsSaving(true);
    try {
      const res = await fetch(`${API}/api/v1/users/me`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          height: parseFloat(height) || null,
          current_weight: parseFloat(currentWeight) || null,
          target_weight: parseFloat(targetWeight) || null,
          activity_level: activityLevel,
        }),
      });

      if (res.ok) {
        showToast("Targets recalculated! ✓", "success");
        fetchData();
      } else {
        showToast("Failed to update measurements", "error");
      }
    } catch {
      showToast("Failed to update measurements", "error");
    } finally {
      setIsSaving(false);
    }
  };

  const savePreferences = async () => {
    setIsSaving(true);
    try {
      const res = await fetch(`${API}/api/v1/users/me`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          primary_goal: primaryGoal,
          dietary_preferences: dietaryPrefs,
          food_allergies: allergies,
        }),
      });

      if (res.ok) {
        showToast("Preferences saved!", "success");
        fetchData();
      } else {
        showToast("Failed to save preferences", "error");
      }
    } catch {
      showToast("Failed to save preferences", "error");
    } finally {
      setIsSaving(false);
    }
  };

  const logNewWeight = async () => {
    if (!logWeight) return;
    try {
      const res = await fetch(`${API}/api/v1/tracker/weight?weight=${logWeight}&note=`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });

      if (res.ok) {
        showToast("Weight logged!", "success");
        setLogWeight("");
        // Refresh weight history
        const weightRes = await fetch(`${API}/api/v1/tracker/weight/history`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (weightRes.ok) {
          setWeightHistory(await weightRes.json());
        }
      }
    } catch {
      showToast("Failed to log weight", "error");
    }
  };

  const toggleChip = (value: string, current: string[], setter: (v: string[]) => void) => {
    if (current.includes(value)) {
      setter(current.filter((v) => v !== value));
    } else {
      setter([...current, value]);
    }
  };

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-6">
          <div className="h-8 bg-[#1a1a1a] rounded w-48" />
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
            <div className="lg:col-span-3 space-y-6">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-64 bg-[#1a1a1a] rounded-2xl" />
              ))}
            </div>
            <div className="lg:col-span-2 space-y-6">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-48 bg-[#1a1a1a] rounded-2xl" />
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  const bmi = calculateBMI(profile?.current_weight || 0, profile?.height || 0);
  const bmiCategory = getBMICategory(bmi);
  const initials = profile?.full_name?.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2) || profile?.email?.[0]?.toUpperCase() || "U";
  const showPaceSlider = primaryGoal === "lose_weight" || primaryGoal === "gain_muscle";

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Toast */}
      {toast && (
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0 }}
          className={`fixed top-4 right-4 px-4 py-3 rounded-xl text-sm font-medium z-50 ${
            toast.type === "success"
              ? "bg-green-500/20 border border-green-500/50 text-green-400"
              : "bg-red-500/20 border border-red-500/50 text-red-400"
          }`}
        >
          {toast.message}
        </motion.div>
      )}

      <h1 className="text-2xl font-bold text-white mb-6">My Profile</h1>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* LEFT COLUMN - 60% */}
        <div className="lg:col-span-3 space-y-6">
          {/* Card 1: Personal Info */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">Personal Information</h2>
            <div className="flex items-start gap-6">
              {/* Avatar */}
              <div className="flex flex-col items-center gap-2">
                <div className="w-20 h-20 rounded-full bg-[#22c55e] flex items-center justify-center">
                  <span className="text-black text-2xl font-bold">{initials}</span>
                </div>
                <button className="flex items-center gap-1 text-gray-400 hover:text-white text-xs">
                  <Camera className="w-3 h-3" />
                  Upload
                </button>
              </div>

              {/* Fields */}
              <div className="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-gray-500 text-xs mb-1 block">Full Name</label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                    <input
                      type="text"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-gray-500 text-xs mb-1 block">Email</label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                    <input
                      type="email"
                      value={profile?.email || ""}
                      readOnly
                      className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-500 cursor-not-allowed"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-gray-500 text-xs mb-1 block">Date of Birth</label>
                  <div className="relative">
                    <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                    <input
                      type="date"
                      value={dateOfBirth}
                      onChange={(e) => setDateOfBirth(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-gray-500 text-xs mb-1 block">Sex</label>
                  <div className="flex gap-2">
                    {["male", "female", "prefer_not_to_say"].map((s) => (
                      <button
                        key={s}
                        onClick={() => setSex(s)}
                        className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition-all ${
                          sex === s
                            ? "bg-[#22c55e] text-black"
                            : "bg-[#1a1a1a] text-gray-400 hover:bg-[#2a2a2a]"
                        }`}
                      >
                        {s === "prefer_not_to_say" ? "Prefer not to say" : s.charAt(0).toUpperCase() + s.slice(1)}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
            <button
              onClick={saveProfile}
              disabled={isSaving}
              className="mt-4 w-full py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <Save className="w-4 h-4" />
              Save Changes
            </button>
          </div>

          {/* Card 2: Measurements */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">Measurements</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
              <div>
                <label className="text-gray-500 text-xs mb-1 block">Height (cm)</label>
                <div className="relative">
                  <Ruler className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    type="number"
                    value={height}
                    onChange={(e) => setHeight(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    placeholder="170"
                  />
                </div>
              </div>
              <div>
                <label className="text-gray-500 text-xs mb-1 block">Current Weight (kg)</label>
                <div className="relative">
                  <Weight className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    type="number"
                    value={currentWeight}
                    onChange={(e) => setCurrentWeight(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    placeholder="70"
                  />
                </div>
              </div>
              <div>
                <label className="text-gray-500 text-xs mb-1 block">Target Weight (kg)</label>
                <div className="relative">
                  <Target className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    type="number"
                    value={targetWeight}
                    onChange={(e) => setTargetWeight(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    placeholder="65"
                  />
                </div>
              </div>
            </div>

            <div className="mb-4">
              <label className="text-gray-500 text-xs mb-1 block">Activity Level</label>
              <select
                value={activityLevel}
                onChange={(e) => setActivityLevel(e.target.value)}
                className="w-full px-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
              >
                {ACTIVITY_LEVELS.map((level) => (
                  <option key={level.value} value={level.value}>
                    {level.label}
                  </option>
                ))}
              </select>
            </div>

            {showPaceSlider && (
              <div className="mb-4">
                <label className="text-gray-500 text-xs mb-1 block">
                  Weight Goal Pace: {goalPace} kg/week
                </label>
                <input
                  type="range"
                  min="0.25"
                  max="1.0"
                  step="0.25"
                  value={goalPace}
                  onChange={(e) => setGoalPace(e.target.value)}
                  className="w-full accent-green-500"
                />
              </div>
            )}

            <button
              onClick={saveMeasurements}
              disabled={isSaving}
              className="w-full py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <Save className="w-4 h-4" />
              Save & Recalculate
            </button>
          </div>

          {/* Card 3: Dietary Preferences */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">Dietary Preferences</h2>

            {/* Primary Goal */}
            <div className="mb-6">
              <label className="text-gray-500 text-xs mb-2 block">Primary Goal</label>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                {GOALS.map((goal) => (
                  <button
                    key={goal.value}
                    onClick={() => setPrimaryGoal(goal.value)}
                    className={`py-3 px-4 rounded-xl text-sm font-medium transition-all flex items-center justify-center gap-2 ${
                      primaryGoal === goal.value
                        ? "bg-[#22c55e] text-black"
                        : "bg-[#1a1a1a] text-gray-400 hover:bg-[#2a2a2a]"
                    }`}
                  >
                    <span>{goal.emoji}</span>
                    <span>{goal.label}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Dietary Preferences */}
            <div className="mb-6">
              <label className="text-gray-500 text-xs mb-2 block">Dietary Preferences</label>
              <div className="flex flex-wrap gap-2">
                {DIETARY_OPTIONS.map((pref) => (
                  <button
                    key={pref}
                    onClick={() => toggleChip(pref, dietaryPrefs, setDietaryPrefs)}
                    className={`px-3 py-1.5 rounded-full text-xs font-medium transition-all ${
                      dietaryPrefs.includes(pref)
                        ? "bg-green-500/20 text-green-400 border border-green-500/50"
                        : "bg-[#1a1a1a] text-gray-400 border border-[#2a2a2a]"
                    }`}
                  >
                    {pref}
                  </button>
                ))}
              </div>
            </div>

            {/* Food Allergies */}
            <div className="mb-6">
              <label className="text-gray-500 text-xs mb-2 block">Food Allergies / Intolerances</label>
              <div className="flex flex-wrap gap-2">
                {ALLERGY_OPTIONS.map((allergy) => (
                  <button
                    key={allergy}
                    onClick={() => toggleChip(allergy, allergies, setAllergies)}
                    className={`px-3 py-1.5 rounded-full text-xs font-medium transition-all ${
                      allergies.includes(allergy)
                        ? "bg-red-500/20 text-red-400 border border-red-500/50"
                        : "bg-[#1a1a1a] text-gray-400 border border-[#2a2a2a]"
                    }`}
                  >
                    {allergy}
                  </button>
                ))}
              </div>
            </div>

            <button
              onClick={savePreferences}
              disabled={isSaving}
              className="w-full py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <Save className="w-4 h-4" />
              Save Preferences
            </button>
          </div>
        </div>

        {/* RIGHT COLUMN - 40% */}
        <div className="lg:col-span-2 space-y-6">
          {/* Card 4: Daily Targets */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-1">Your Daily Targets</h2>
            <p className="text-gray-500 text-xs mb-4">Calculated from your profile</p>

            <div className="grid grid-cols-2 gap-3 mb-6">
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Flame className="w-5 h-5 text-orange-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.daily_cal_target || 2000}</span>
                <span className="text-xs text-gray-500">Calories kcal</span>
              </div>
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Beef className="w-5 h-5 text-blue-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.protein_target || 150}g</span>
                <span className="text-xs text-gray-500">Protein</span>
              </div>
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Wheat className="w-5 h-5 text-orange-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.carbs_target || 250}g</span>
                <span className="text-xs text-gray-500">Carbs</span>
              </div>
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Droplet className="w-5 h-5 text-purple-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.fat_target || 65}g</span>
                <span className="text-xs text-gray-500">Fat</span>
              </div>
            </div>

            {/* BMI */}
            {bmi > 0 && (
              <div className="bg-[#1a1a1a] rounded-xl p-4 mb-4">
                <div className="flex items-center justify-between">
                  <span className="text-gray-400 text-sm">BMI</span>
                  <span className={`font-semibold ${bmiCategory.color}`}>
                    {bmi.toFixed(1)} - {bmiCategory.label}
                  </span>
                </div>
              </div>
            )}

            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500">BMR (base)</span>
                <span className="text-white">{profile?.bmr || "—"} kcal/day</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">TDEE (with activity)</span>
                <span className="text-white">{profile?.tdee || "—"} kcal/day</span>
              </div>
            </div>
            <p className="text-gray-600 text-xs mt-4">
              Targets update automatically when you save measurements
            </p>
          </div>

          {/* Card 5: Weight Progress */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">Weight Progress</h2>

            {weightHistory.length > 0 ? (
              <>
                <div className="h-48 mb-4">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={weightHistory}>
                      <XAxis
                        dataKey="date"
                        stroke="#666"
                        fontSize={10}
                        tickFormatter={(v) => v.split("-")[2]}
                      />
                      <YAxis stroke="#666" fontSize={10} domain={["dataMin - 2", "dataMax + 2"]} />
                      <Tooltip
                        contentStyle={{ background: "#1a1a1a", border: "1px solid #333", borderRadius: "8px" }}
                        labelStyle={{ color: "#999" }}
                      />
                      <Line
                        type="monotone"
                        dataKey="weight"
                        stroke="#22c55e"
                        strokeWidth={2}
                        dot={{ fill: "#22c55e", strokeWidth: 0 }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>

                {/* Log new weight */}
                <div className="flex gap-2">
                  <input
                    type="date"
                    value={logDate}
                    onChange={(e) => setLogDate(e.target.value)}
                    className="flex-1 px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <input
                    type="number"
                    value={logWeight}
                    onChange={(e) => setLogWeight(e.target.value)}
                    placeholder="kg"
                    className="w-20 px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <button
                    onClick={logNewWeight}
                    className="px-4 py-2 bg-[#22c55e] text-black rounded-xl text-sm font-medium hover:bg-[#16a34a] transition-colors"
                  >
                    Log
                  </button>
                </div>
              </>
            ) : (
              <div className="text-center py-8">
                <TrendingUp className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                <p className="text-gray-500 text-sm">Start logging your weight to see progress</p>
                <div className="flex gap-2 mt-4">
                  <input
                    type="date"
                    value={logDate}
                    onChange={(e) => setLogDate(e.target.value)}
                    className="flex-1 px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <input
                    type="number"
                    value={logWeight}
                    onChange={(e) => setLogWeight(e.target.value)}
                    placeholder="kg"
                    className="w-20 px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <button
                    onClick={logNewWeight}
                    className="px-4 py-2 bg-[#22c55e] text-black rounded-xl text-sm font-medium hover:bg-[#16a34a] transition-colors"
                  >
                    Log
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* Card 6: Account Stats */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">Account Stats</h2>
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#1a1a1a] flex items-center justify-center">
                  <Clock className="w-5 h-5 text-gray-400" />
                </div>
                <div>
                  <p className="text-gray-500 text-xs">Member since</p>
                  <p className="text-white text-sm">
                    {profile?.created_at ? new Date(profile.created_at).toLocaleDateString("en-US", {
                      month: "long",
                      day: "numeric",
                      year: "numeric",
                    }) : "—"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#1a1a1a] flex items-center justify-center">
                  <Award className="w-5 h-5 text-gray-400" />
                </div>
                <div>
                  <p className="text-gray-500 text-xs">Current Streak</p>
                  <p className="text-white text-sm flex items-center gap-1">
                    0 days <span>🔥</span>
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#1a1a1a] flex items-center justify-center">
                  <Target className="w-5 h-5 text-gray-400" />
                </div>
                <div>
                  <p className="text-gray-500 text-xs">Goal</p>
                  <p className="text-white text-sm">
                    {GOALS.find((g) => g.value === primaryGoal)?.emoji}{" "}
                    {GOALS.find((g) => g.value === primaryGoal)?.label || "Not set"}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}