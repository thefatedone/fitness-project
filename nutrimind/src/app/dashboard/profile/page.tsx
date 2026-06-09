"use client";

import { useState, useEffect } from "react";
import { useTranslation } from "react-i18next";
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
  X,
} from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { motion } from "framer-motion";
import ProfilePhotoCrop from "@/components/dashboard/ProfilePhotoCrop";

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
  profile_photo?: string | null;
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
  "Nuts", "Shellfish", "Eggs", "Soy", "Wheat", "Fish", "Milk"
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
  const { t } = useTranslation();
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
  const [cropModalOpen, setCropModalOpen] = useState(false);
  const [lightboxOpen, setLightboxOpen] = useState(false);

  const token = typeof window !== "undefined" ? localStorage.getItem("nutrimind_token") : null;
  const API = process.env.NEXT_PUBLIC_API_URL;

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
        setDateOfBirth(data.date_of_birth ? data.date_of_birth.split("T")[0] : "");
        setSex(data.sex || "");
        setHeight(data.height?.toString() || "");
        setCurrentWeight(data.current_weight?.toString() || "");
        setTargetWeight(data.target_weight?.toString() || "");
        setActivityLevel(data.activity_level || "moderately_active");
        setPrimaryGoal(data.primary_goal || "maintain");
        setDietaryPrefs(data.dietary_preferences ? data.dietary_preferences.split(",").filter(Boolean) : []);
        setAllergies(data.food_allergies ? data.food_allergies.split(",").filter(Boolean) : []);
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
          Authorization: `Bearer ${localStorage.getItem("nutrimind_token")}`,
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
          dietary_preferences: dietaryPrefs.join(",") || null,
          food_allergies: allergies.join(",") || null,
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
          Authorization: `Bearer ${localStorage.getItem("nutrimind_token")}`,
        },
        body: JSON.stringify({
          height: parseFloat(height) || null,
          current_weight: parseFloat(currentWeight) || null,
          target_weight: parseFloat(targetWeight) || null,
          activity_level: activityLevel,
          primary_goal: primaryGoal,
          dietary_preferences: dietaryPrefs.join(",") || null,
          food_allergies: allergies.join(",") || null,
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
          Authorization: `Bearer ${localStorage.getItem("nutrimind_token")}`,
        },
        body: JSON.stringify({
          primary_goal: primaryGoal,
          dietary_preferences: dietaryPrefs.filter(Boolean).length > 0 ? dietaryPrefs.filter(Boolean).join(",") : null,
          food_allergies: allergies.filter(a => a && a.trim()).length > 0 ? allergies.filter(a => a && a.trim()).join(",") : null,
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

  const handlePhotoCropped = async (base64: string) => {
    try {
      const res = await fetch(`${API}/api/v1/users/me/photo`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ image: base64 }),
      });
      if (res.ok) {
        const { url } = await res.json();
        setProfile((prev) => (prev ? { ...prev, profile_photo: url } : prev));
        showToast("Profile photo updated!", "success");
      } else {
        showToast("Failed to upload photo", "error");
      }
    } catch {
      showToast("Failed to upload photo", "error");
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

      {/* Lightbox for viewing full-size profile photo */}
      {lightboxOpen && profile?.profile_photo && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/95 backdrop-blur-sm"
          onClick={() => setLightboxOpen(false)}
        >
          <motion.div
            initial={{ scale: 0.9 }}
            animate={{ scale: 1 }}
            exit={{ scale: 0.9 }}
            className="relative max-w-2xl max-h-[80vh] w-full mx-4"
            onClick={(e) => e.stopPropagation()}
          >
            <img
              src={`${API}${profile.profile_photo}`}
              alt="Full size"
              className="w-full h-full object-contain rounded-2xl"
            />
            <button
              onClick={() => setLightboxOpen(false)}
              className="absolute top-4 right-4 p-3 bg-white/10 hover:bg-white/20 rounded-full text-white transition-colors"
            >
              <X className="w-6 h-6" />
            </button>
            <p className="text-center text-gray-400 text-sm mt-4">Click outside to close</p>
          </motion.div>
        </motion.div>
      )}

      <h1 className="text-2xl font-bold text-white mb-6">{t("profile.title")}</h1>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* LEFT COLUMN - 60% */}
        <div className="lg:col-span-3 space-y-6">
          {/* Card 1: Personal Info */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">{t("profile.personalInformation")}</h2>
            <div className="flex items-start gap-6">
              {/* Avatar */}
              <div className="flex flex-col items-center gap-2">
                <div
                  className="w-20 h-20 rounded-full bg-[#22c55e] flex items-center justify-center overflow-hidden cursor-pointer group relative"
                  onClick={() => profile?.profile_photo && setLightboxOpen(true)}
                >
                  {profile?.profile_photo ? (
                    <>
                      <img
                        src={`${API}${profile.profile_photo}`}
                        alt="Profile"
                        className="w-full h-full object-cover"
                      />
                      <div className="absolute inset-0 flex items-center justify-center bg-black/50 rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
                        <span className="text-white text-xs">View</span>
                      </div>
                    </>
                  ) : (
                    <span className="text-black text-2xl font-bold">{initials}</span>
                  )}
                </div>
                <button
                  onClick={() => setCropModalOpen(true)}
                  className="flex items-center gap-1 text-gray-400 hover:text-white text-xs transition-colors"
                >
                  <Camera className="w-3 h-3" />
                  {profile?.profile_photo ? "Change" : "Upload"}
                </button>
              </div>

              {/* Fields */}
              <div className="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="fullName" className="text-gray-500 text-xs mb-1 block">{t("profile.fullName")}</label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                    <input
                      id="fullName"
                      type="text"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-gray-500 text-xs mb-1 block">{t("profile.email")}</label>
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
                  <label htmlFor="dateOfBirth" className="text-gray-500 text-xs mb-1 block">{t("profile.dateOfBirth")}</label>
                  <div className="relative">
                    <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                    <input
                      id="dateOfBirth"
                      type="date"
                      value={dateOfBirth}
                      onChange={(e) => setDateOfBirth(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-gray-500 text-xs mb-1 block">{t("profile.sex")}</label>
                  <div className="flex gap-2">
                    {[
                      { value: "male", label: t("profile.male") },
                      { value: "female", label: t("profile.female") },
                      { value: "prefer_not_to_say", label: t("profile.preferNotToSay") },
                    ].map((s) => (
                      <button
                        key={s.value}
                        onClick={() => setSex(s.value)}
                        className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition-all ${
                          sex === s.value
                            ? "bg-[#22c55e] text-black"
                            : "bg-[#1a1a1a] text-gray-400 hover:bg-[#2a2a2a]"
                        }`}
                      >
                        {s.label}
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
              {t("profile.saveChanges")}
            </button>
          </div>

          {/* Card 2: Measurements */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">{t("profile.measurements")}</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
              <div>
                <label htmlFor="height" className="text-gray-500 text-xs mb-1 block">{t("profile.heightCm")}</label>
                <div className="relative">
                  <Ruler className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    id="height"
                    type="number"
                    value={height}
                    onChange={(e) => setHeight(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    placeholder="170"
                  />
                </div>
              </div>
              <div>
                <label htmlFor="currentWeight" className="text-gray-500 text-xs mb-1 block">{t("profile.currentWeightKg")}</label>
                <div className="relative">
                  <Weight className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    id="currentWeight"
                    type="number"
                    value={currentWeight}
                    onChange={(e) => setCurrentWeight(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
                    placeholder="70"
                  />
                </div>
              </div>
              <div>
                <label htmlFor="targetWeight" className="text-gray-500 text-xs mb-1 block">{t("profile.targetWeightKg")}</label>
                <div className="relative">
                  <Target className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    id="targetWeight"
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
              <label htmlFor="activityLevel" className="text-gray-500 text-xs mb-1 block">{t("profile.activityLevel")}</label>
              <select
                id="activityLevel"
                value={activityLevel}
                onChange={(e) => setActivityLevel(e.target.value)}
                className="w-full px-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 transition-colors"
              >
                {ACTIVITY_LEVELS.map((level) => (
                  <option key={level.value} value={level.value}>
                    {level.label === "Lightly Active" ? t("profile.lightlyActive") : level.label}
                  </option>
                ))}
              </select>
            </div>

            {showPaceSlider && (
              <div className="mb-4">
                <label htmlFor="goalPace" className="text-gray-500 text-xs mb-1 block">
                  {t("profile.weightGoalPace")}: {goalPace} {t("profile.kgPerWeek")}
                </label>
                <input
                  id="goalPace"
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
              {t("profile.saveAndRecalculate")}
            </button>
          </div>

          {/* Card 3: Dietary Preferences */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">{t("profile.dietaryPreferences")}</h2>

            {/* Primary Goal */}
            <div className="mb-6">
              <label className="text-gray-500 text-xs mb-2 block">{t("profile.primaryGoal")}</label>
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
              <label className="text-gray-500 text-xs mb-2 block">{t("profile.dietaryPreferences")}</label>
              <div className="space-y-3">
                {dietaryPrefs.map((_, index) => (
                  <div key={index} className="flex gap-2">
                    <input
                      type="text"
                      placeholder={index === 0 ? "e.g. Keto, Vegetarian, Paleo..." : `Dietary preference #${index + 1}`}
                      value={dietaryPrefs[index] || ""}
                      onChange={(e) => {
                        const updated = [...dietaryPrefs];
                        updated[index] = e.target.value;
                        setDietaryPrefs(updated);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && dietaryPrefs[index]?.trim()) {
                          e.preventDefault();
                          if (dietaryPrefs.length < 3) {
                            setDietaryPrefs([...dietaryPrefs, ""]);
                          }
                        }
                      }}
                      className="flex-1 px-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-green-500 transition-all text-sm"
                    />
                    {dietaryPrefs.length > 1 && (
                      <button
                        type="button"
                        onClick={() => setDietaryPrefs(dietaryPrefs.filter((_, i) => i !== index))}
                        className="px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-500 hover:text-red-400 hover:border-red-500/50 transition-all"
                      >
                        ✕
                      </button>
                    )}
                  </div>
                ))}
                {dietaryPrefs.length < 3 && (
                  <button
                    type="button"
                    onClick={() => setDietaryPrefs([...dietaryPrefs, ""])}
                    className="w-full py-2 border border-dashed border-[#2a2a2a] rounded-xl text-gray-500 hover:text-green-400 hover:border-green-500/50 transition-all text-sm"
                  >
                    + Add another preference
                  </button>
                )}
              </div>
            </div>

            {/* Food Allergies */}
            <div className="mb-6">
              <label className="text-gray-500 text-xs mb-2 block">Food Allergies / Intolerances</label>
              <div className="space-y-3">
                {allergies.map((_, index) => (
                  <div key={index} className="flex gap-2">
                    <input
                      type="text"
                      placeholder={index === 0 ? "e.g. Nuts, Gluten, Dairy..." : `Food preference #${index + 1}`}
                      value={allergies[index] || ""}
                      onChange={(e) => {
                        const updated = [...allergies];
                        updated[index] = e.target.value;
                        setAllergies(updated);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && allergies[index]?.trim()) {
                          e.preventDefault();
                          if (allergies.length < 3) {
                            setAllergies([...allergies, ""]);
                          }
                        }
                      }}
                      className="flex-1 px-4 py-2.5 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-green-500 transition-all text-sm"
                    />
                    {allergies.length > 1 && (
                      <button
                        type="button"
                        onClick={() => setAllergies(allergies.filter((_, i) => i !== index))}
                        className="px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-500 hover:text-red-400 hover:border-red-500/50 transition-all"
                      >
                        ✕
                      </button>
                    )}
                  </div>
                ))}
                {allergies.length < 3 && (
                  <button
                    type="button"
                    onClick={() => setAllergies([...allergies, ""])}
                    className="w-full py-2 border border-dashed border-[#2a2a2a] rounded-xl text-gray-500 hover:text-green-400 hover:border-green-500/50 transition-all text-sm"
                  >
                    + Add another allergy
                  </button>
                )}
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
            <h2 className="text-white font-semibold mb-1">{t("profile.yourDailyTargets")}</h2>
            <p className="text-gray-500 text-xs mb-4">{t("profile.calculatedFromProfile")}</p>

            <div className="grid grid-cols-2 gap-3 mb-6">
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Flame className="w-5 h-5 text-orange-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.daily_cal_target || 2000}</span>
                <span className="text-xs text-gray-500">{t("profile.caloriesKcal")}</span>
              </div>
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Beef className="w-5 h-5 text-blue-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.protein_target || 150}g</span>
                <span className="text-xs text-gray-500">{t("profile.protein")}</span>
              </div>
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Wheat className="w-5 h-5 text-orange-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.carbs_target || 250}g</span>
                <span className="text-xs text-gray-500">{t("profile.carbs")}</span>
              </div>
              <div className="bg-[#1a1a1a] rounded-xl p-4 flex flex-col items-center">
                <Droplet className="w-5 h-5 text-purple-400 mb-2" />
                <span className="text-2xl font-bold text-white">{profile?.fat_target || 65}g</span>
                <span className="text-xs text-gray-500">{t("profile.fat")}</span>
              </div>
            </div>

            {/* BMI */}
            {bmi > 0 && (
              <div className="bg-[#1a1a1a] rounded-xl p-4 mb-4">
                <div className="flex items-center justify-between">
                  <span className="text-gray-400 text-sm">{t("profile.bmi")}</span>
                  <span className={`font-semibold ${bmiCategory.color}`}>
                    {bmi.toFixed(1)} - {bmiCategory.label === "Obese" ? t("profile.obese") : bmiCategory.label}
                  </span>
                </div>
              </div>
            )}

            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500">{t("profile.bmrBase")}</span>
                <span className="text-white">{profile?.bmr || "—"} {t("profile.kcalPerDay")}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">{t("profile.tdeeWithActivity")}</span>
                <span className="text-white">{profile?.tdee || "—"} {t("profile.kcalPerDay")}</span>
              </div>
            </div>
            <p className="text-gray-600 text-xs mt-4">
              {t("profile.targetsUpdateAutomatically")}
            </p>
          </div>

          {/* Card 5: Weight Progress */}
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
            <h2 className="text-white font-semibold mb-4">{t("profile.weightProgress")}</h2>

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
                    id="logDate"
                    type="date"
                    value={logDate}
                    onChange={(e) => setLogDate(e.target.value)}
                    className="flex-1 px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <input
                    id="logWeight"
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
                    {t("profile.log")}
                  </button>
                </div>
              </>
            ) : (
              <div className="text-center py-8">
                <TrendingUp className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                <p className="text-gray-500 text-sm">{t("profile.startLoggingWeight")}</p>
                <div className="flex gap-2 mt-4">
                  <input
                    id="logDate"
                    type="date"
                    value={logDate}
                    onChange={(e) => setLogDate(e.target.value)}
                    className="flex-1 px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <input
                    id="logWeight"
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
                    {t("profile.log")}
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

      {/* Profile Photo Crop Modal */}
      <ProfilePhotoCrop
        isOpen={cropModalOpen}
        onClose={() => setCropModalOpen(false)}
        onCropped={handlePhotoCropped}
        currentPhoto={profile?.profile_photo ? `${API}${profile.profile_photo}` : undefined}
      />
    </div>
  );
}
