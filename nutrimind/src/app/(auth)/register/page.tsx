"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useRouter } from "next/navigation";
import { Check, Mail, Phone, Lock, Eye, EyeOff, ArrowRight, ArrowLeft, User, Ruler, Target } from "lucide-react";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

interface FormData {
  email: string;
  phone: string;
  loginMethod: "email" | "phone";
  name: string;
  password: string;
  confirmPassword: string;
  termsAccepted: boolean;
  dateOfBirth: string;
  sex: string;
  profilePhoto: string;
  height: number | null;
  heightUnit: "cm" | "ft";
  currentWeight: number | null;
  weightUnit: "kg" | "lbs";
  targetWeight: number | null;
  activityLevel: string;
  primaryGoal: string;
  dietaryPrefs: string[];
  allergies: string[];
  weightPace: number;
}

const dietaryOptions = [
  "Vegan", "Vegetarian", "Keto", "Paleo",
  "Mediterranean", "Gluten-free", "Dairy-free"
];

const allergyOptions = [
  "Nuts", "Shellfish", "Eggs", "Soy", "Wheat", "Fish", "Milk"
];

const activityLevels = [
  { id: "sedentary", icon: "🪑", label: "Sedentary", desc: "Desk job, little exercise" },
  { id: "light", icon: "🚶", label: "Lightly Active", desc: "Exercise 1-3 days/week" },
  { id: "moderate", icon: "🏃", label: "Moderately Active", desc: "Exercise 3-5 days/week" },
  { id: "very_active", icon: "💪", label: "Very Active", desc: "Hard exercise 6-7 days/week" },
  { id: "extra_active", icon: "🔥", label: "Extra Active", desc: "Physical job + daily training" },
];

const goalOptions = [
  { id: "lose_weight", icon: "🔥", label: "Lose Weight" },
  { id: "maintain", icon: "⚖️", label: "Maintain Weight" },
  { id: "gain_muscle", icon: "💪", label: "Gain Muscle" },
  { id: "eat_healthier", icon: "🥗", label: "Eat Healthier" },
];

const sexOptions = [
  { id: "male", icon: "♂", label: "Male" },
  { id: "female", icon: "♀", label: "Female" },
  { id: "other", icon: "⚥", label: "Prefer not to say" },
];

export default function RegisterPage() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const [formData, setFormData] = useState<FormData>({
    email: "",
    phone: "",
    loginMethod: "email",
    name: "",
    password: "",
    confirmPassword: "",
    termsAccepted: false,
    dateOfBirth: "",
    sex: "",
    profilePhoto: "",
    height: null,
    heightUnit: "cm",
    currentWeight: null,
    weightUnit: "kg",
    targetWeight: null,
    activityLevel: "",
    primaryGoal: "",
    dietaryPrefs: [],
    allergies: [],
    weightPace: 0.5,
  });

  const updateField = <K extends keyof FormData>(key: K, value: FormData[K]) => {
    setFormData((prev) => ({ ...prev, [key]: value }));
  };

  const getToken = () => localStorage.getItem("nutrimind_token");

  const handleNext = () => setStep((s) => Math.min(s + 1, 4));
  const handleBack = () => setStep((s) => Math.max(s - 1, 1));

  const slideVariants = {
    enter: (direction: number) => ({
      x: direction > 0 ? 300 : -300,
      opacity: 0,
    }),
    center: {
      x: 0,
      opacity: 1,
    },
    exit: (direction: number) => ({
      x: direction < 0 ? 300 : -300,
      opacity: 0,
    }),
  };

  const handleStep1Submit = () => {
    if (formData.password !== formData.confirmPassword) {
      setError("Passwords do not match");
      return;
    }
    if (!formData.termsAccepted) {
      setError("Please accept the terms");
      return;
    }
    setError("");
    handleNext();
  };

  const handleFinalSubmit = async () => {
    setIsLoading(true);
    setError("");

    try {
      // Step 1: Register
      const registerRes = await fetch(`${API_URL}/api/v1/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          [formData.loginMethod]: formData.loginMethod === "email" ? formData.email : formData.phone,
          password: formData.password,
          name: formData.name,
        }),
      });

      const registerData = await registerRes.json();
      if (!registerRes.ok) {
        setError(registerData.detail || "Registration failed");
        return;
      }

      localStorage.setItem("nutrimind_token", registerData.access_token);
      const token = registerData.access_token;

      // Calculate age from DOB
      const dob = new Date(formData.dateOfBirth);
      const age = Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 60 * 60 * 1000));

      // Convert height to cm if needed
      let heightCm = formData.height;
      if (formData.heightUnit === "ft") {
        heightCm = (formData.height || 0) * 30.48;
      }

      // Convert weight to kg if needed
      let weightKg = formData.currentWeight;
      if (formData.weightUnit === "lbs") {
        weightKg = (formData.currentWeight || 0) * 0.453592;
      }
      let targetWeightKg = formData.targetWeight;
      if (formData.weightUnit === "lbs") {
        targetWeightKg = (formData.targetWeight || 0) * 0.453592;
      }

      // Step 2: Update profile
      const profileRes = await fetch(`${API_URL}/api/v1/users/me`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
          date_of_birth: formData.dateOfBirth,
          sex: formData.sex,
          height: heightCm,
          current_weight: weightKg,
          target_weight: targetWeightKg,
          activity_level: formData.activityLevel,
          primary_goal: formData.primaryGoal,
          dietary_prefs: formData.dietaryPrefs.join(","),
          allergies: formData.allergies.join(","),
          weight_loss_pace: formData.weightPace,
        }),
      });

      if (!profileRes.ok) {
        const profileData = await profileRes.json();
        console.error("Profile update failed:", profileData);
      }

      router.push("/dashboard/tracker");
    } catch {
      setError("Unable to connect to server");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
      className="w-full max-w-lg"
    >
      <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-8">
        {/* Logo */}
        <div className="flex items-center justify-center gap-2 mb-6">
          <div className="w-10 h-10 rounded-xl bg-[#22c55e] flex items-center justify-center">
            <span className="text-black font-bold text-xl">N</span>
          </div>
          <span className="text-white font-bold text-xl">NutriMind</span>
        </div>

        {/* Progress Bar */}
        <div className="flex items-center justify-center gap-2 mb-8">
          {[1, 2, 3, 4].map((s) => (
            <div key={s} className="flex items-center">
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all duration-300 ${
                  s < step
                    ? "bg-[#22c55e] text-black"
                    : s === step
                    ? "bg-[#22c55e] text-black ring-4 ring-[#22c55e]/20"
                    : "bg-[#1a1a1a] text-gray-500"
                }`}
              >
                {s < step ? <Check className="w-4 h-4" /> : s}
              </div>
              {s < 4 && (
                <div className={`w-8 h-0.5 ${s < step ? "bg-[#22c55e]" : "bg-[#1a1a1a]"}`} />
              )}
            </div>
          ))}
        </div>

        {error && (
          <div className="mb-6 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm text-center">
            {error}
          </div>
        )}

        <AnimatePresence mode="wait" custom={1}>
          {/* STEP 1: Account */}
          {step === 1 && (
            <motion.div
              key="step1"
              custom={1}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.3, ease: [0.32, 0.72, 0, 1] }}
            >
              <h2 className="text-xl font-bold text-white mb-2">Create your account</h2>
              <p className="text-gray-500 text-sm mb-6">Step 1 of 4 — Account details</p>

              {/* Login Method Toggle */}
              <div className="flex rounded-xl bg-[#1a1a1a] p-1 mb-5">
                <button
                  type="button"
                  onClick={() => updateField("loginMethod", "email")}
                  className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all duration-300 ${
                    formData.loginMethod === "email" ? "bg-[#22c55e] text-black" : "text-gray-400"
                  }`}
                >
                  Email
                </button>
                <button
                  type="button"
                  onClick={() => updateField("loginMethod", "phone")}
                  className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all duration-300 ${
                    formData.loginMethod === "phone" ? "bg-[#22c55e] text-black" : "text-gray-400"
                  }`}
                >
                  Phone
                </button>
              </div>

              {/* Email or Phone */}
              <div className="relative mb-4">
                {formData.loginMethod === "email" ? (
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                ) : (
                  <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                )}
                <input
                  type={formData.loginMethod === "email" ? "email" : "tel"}
                  placeholder={formData.loginMethod === "email" ? "Email address" : "Phone number"}
                  value={formData.loginMethod === "email" ? formData.email : formData.phone}
                  onChange={(e) => updateField(formData.loginMethod, e.target.value)}
                  className="w-full pl-12 pr-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all"
                />
              </div>

              {/* Name */}
              <div className="relative mb-4">
                <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="text"
                  placeholder="Full name"
                  value={formData.name}
                  onChange={(e) => updateField("name", e.target.value)}
                  className="w-full pl-12 pr-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all"
                />
              </div>

              {/* Password */}
              <div className="relative mb-4">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="password"
                  placeholder="Password"
                  value={formData.password}
                  onChange={(e) => updateField("password", e.target.value)}
                  className="w-full pl-12 pr-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all"
                />
              </div>

              {/* Confirm Password */}
              <div className="relative mb-5">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="password"
                  placeholder="Confirm password"
                  value={formData.confirmPassword}
                  onChange={(e) => updateField("confirmPassword", e.target.value)}
                  className="w-full pl-12 pr-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all"
                />
              </div>

              {/* Terms */}
              <label className="flex items-center gap-3 mb-6 cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.termsAccepted}
                  onChange={(e) => updateField("termsAccepted", e.target.checked)}
                  className="w-5 h-5 rounded bg-[#1a1a1a] border border-[#2a2a2a] accent-[#22c55e]"
                />
                <span className="text-gray-400 text-sm">
                  I agree to the{" "}
                  <a href="#" className="text-[#22c55e] hover:underline">Terms of Service</a>
                </span>
              </label>

              <button
                onClick={handleStep1Submit}
                className="w-full py-3.5 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all flex items-center justify-center gap-2"
              >
                Continue <ArrowRight className="w-4 h-4" />
              </button>
            </motion.div>
          )}

          {/* STEP 2: Profile */}
          {step === 2 && (
            <motion.div
              key="step2"
              custom={1}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.3, ease: [0.32, 0.72, 0, 1] }}
            >
              <h2 className="text-xl font-bold text-white mb-2">Tell us about yourself</h2>
              <p className="text-gray-500 text-sm mb-6">Step 2 of 4 — Basic info</p>

              {/* Date of Birth */}
              <div className="mb-5">
                <label className="block text-gray-400 text-sm mb-2">Date of Birth</label>
                <input
                  type="date"
                  value={formData.dateOfBirth}
                  onChange={(e) => updateField("dateOfBirth", e.target.value)}
                  className="w-full px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all"
                />
              </div>

              {/* Sex Selection */}
              <div className="mb-6">
                <label className="block text-gray-400 text-sm mb-2">Sex</label>
                <div className="grid grid-cols-3 gap-3">
                  {sexOptions.map((opt) => (
                    <button
                      key={opt.id}
                      type="button"
                      onClick={() => updateField("sex", opt.id)}
                      className={`p-4 rounded-xl border transition-all duration-300 flex flex-col items-center gap-2 ${
                        formData.sex === opt.id
                          ? "border-[#22c55e] bg-[#22c55e]/10 text-[#22c55e]"
                          : "border-[#2a2a2a] bg-[#1a1a1a] text-gray-400 hover:border-gray-600"
                      }`}
                    >
                      <span className="text-2xl">{opt.icon}</span>
                      <span className="text-sm font-medium">{opt.label}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={handleBack}
                  className="flex-1 py-3.5 rounded-xl bg-[#1a1a1a] text-white font-medium hover:bg-[#222222] active:scale-[0.98] transition-all flex items-center justify-center gap-2"
                >
                  <ArrowLeft className="w-4 h-4" /> Back
                </button>
                <button
                  onClick={handleNext}
                  disabled={!formData.dateOfBirth || !formData.sex}
                  className="flex-1 py-3.5 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  Continue <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </motion.div>
          )}

          {/* STEP 3: Measurements */}
          {step === 3 && (
            <motion.div
              key="step3"
              custom={1}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.3, ease: [0.32, 0.72, 0, 1] }}
            >
              <h2 className="text-xl font-bold text-white mb-2">Your measurements</h2>
              <p className="text-gray-500 text-sm mb-6">Step 3 of 4 — Body stats</p>

              {/* Height */}
              <div className="mb-4">
                <label className="block text-gray-400 text-sm mb-2">Height</label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    placeholder={formData.heightUnit === "cm" ? "175" : "5'9\""}
                    value={formData.height || ""}
                    onChange={(e) => updateField("height", parseFloat(e.target.value) || null)}
                    className="flex-1 px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 transition-all"
                  />
                  <button
                    onClick={() => updateField("heightUnit", formData.heightUnit === "cm" ? "ft" : "cm")}
                    className="px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-400 hover:text-white transition-all"
                  >
                    {formData.heightUnit}
                  </button>
                </div>
              </div>

              {/* Current Weight */}
              <div className="mb-4">
                <label className="block text-gray-400 text-sm mb-2">Current Weight</label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    placeholder={formData.weightUnit === "kg" ? "70" : "154"}
                    value={formData.currentWeight || ""}
                    onChange={(e) => updateField("currentWeight", parseFloat(e.target.value) || null)}
                    className="flex-1 px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 transition-all"
                  />
                  <button
                    onClick={() => updateField("weightUnit", formData.weightUnit === "kg" ? "lbs" : "kg")}
                    className="px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-400 hover:text-white transition-all"
                  >
                    {formData.weightUnit}
                  </button>
                </div>
              </div>

              {/* Target Weight */}
              <div className="mb-5">
                <label className="block text-gray-400 text-sm mb-2">Target Weight</label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    placeholder={formData.weightUnit === "kg" ? "65" : "143"}
                    value={formData.targetWeight || ""}
                    onChange={(e) => updateField("targetWeight", parseFloat(e.target.value) || null)}
                    className="flex-1 px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 transition-all"
                  />
                  <div className="px-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-gray-400">
                    {formData.weightUnit}
                  </div>
                </div>
              </div>

              {/* Activity Level */}
              <div className="mb-6">
                <label className="block text-gray-400 text-sm mb-3">Activity Level</label>
                <div className="space-y-2">
                  {activityLevels.map((level) => (
                    <button
                      key={level.id}
                      type="button"
                      onClick={() => updateField("activityLevel", level.id)}
                      className={`w-full p-3 rounded-xl border flex items-center gap-3 transition-all duration-300 ${
                        formData.activityLevel === level.id
                          ? "border-[#22c55e] bg-[#22c55e]/10"
                          : "border-[#2a2a2a] bg-[#1a1a1a] hover:border-gray-600"
                      }`}
                    >
                      <span className="text-xl">{level.icon}</span>
                      <div className="text-left">
                        <div className={`text-sm font-medium ${formData.activityLevel === level.id ? "text-[#22c55e]" : "text-white"}`}>
                          {level.label}
                        </div>
                        <div className="text-xs text-gray-500">{level.desc}</div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={handleBack}
                  className="flex-1 py-3.5 rounded-xl bg-[#1a1a1a] text-white font-medium hover:bg-[#222222] active:scale-[0.98] transition-all flex items-center justify-center gap-2"
                >
                  <ArrowLeft className="w-4 h-4" /> Back
                </button>
                <button
                  onClick={handleNext}
                  disabled={!formData.height || !formData.currentWeight || !formData.activityLevel}
                  className="flex-1 py-3.5 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  Continue <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </motion.div>
          )}

          {/* STEP 4: Goals */}
          {step === 4 && (
            <motion.div
              key="step4"
              custom={1}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.3, ease: [0.32, 0.72, 0, 1] }}
            >
              <h2 className="text-xl font-bold text-white mb-2">What&apos;s your goal?</h2>
              <p className="text-gray-500 text-sm mb-6">Step 4 of 4 — Final step</p>

              {/* Primary Goal */}
              <div className="mb-5">
                <label className="block text-gray-400 text-sm mb-3">Primary Goal</label>
                <div className="grid grid-cols-2 gap-3">
                  {goalOptions.map((goal) => (
                    <button
                      key={goal.id}
                      type="button"
                      onClick={() => updateField("primaryGoal", goal.id)}
                      className={`p-4 rounded-xl border transition-all duration-300 flex flex-col items-center gap-2 ${
                        formData.primaryGoal === goal.id
                          ? "border-[#22c55e] bg-[#22c55e]/10"
                          : "border-[#2a2a2a] bg-[#1a1a1a] hover:border-gray-600"
                      }`}
                    >
                      <span className="text-2xl">{goal.icon}</span>
                      <span className={`text-sm font-medium ${formData.primaryGoal === goal.id ? "text-[#22c55e]" : "text-white"}`}>
                        {goal.label}
                      </span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Dietary Preferences */}
              <div className="mb-5">
                <label className="block text-gray-400 text-sm mb-3">Dietary Preferences</label>
                <div className="flex flex-wrap gap-2">
                  {dietaryOptions.map((pref) => (
                    <button
                      key={pref}
                      type="button"
                      onClick={() => {
                        const current = formData.dietaryPrefs;
                        if (current.includes(pref)) {
                          updateField("dietaryPrefs", current.filter((p) => p !== pref));
                        } else {
                          updateField("dietaryPrefs", [...current, pref]);
                        }
                      }}
                      className={`px-3 py-1.5 rounded-full text-sm transition-all duration-300 ${
                        formData.dietaryPrefs.includes(pref)
                          ? "bg-[#22c55e] text-black"
                          : "bg-[#1a1a1a] text-gray-400 border border-[#2a2a2a] hover:border-gray-600"
                      }`}
                    >
                      {pref}
                    </button>
                  ))}
                </div>
              </div>

              {/* Allergies */}
              <div className="mb-5">
                <label className="block text-gray-400 text-sm mb-3">Food Allergies</label>
                <div className="flex flex-wrap gap-2">
                  {allergyOptions.map((allergy) => (
                    <button
                      key={allergy}
                      type="button"
                      onClick={() => {
                        const current = formData.allergies;
                        if (current.includes(allergy)) {
                          updateField("allergies", current.filter((a) => a !== allergy));
                        } else {
                          updateField("allergies", [...current, allergy]);
                        }
                      }}
                      className={`px-3 py-1.5 rounded-full text-sm transition-all duration-300 ${
                        formData.allergies.includes(allergy)
                          ? "bg-red-500/20 text-red-400 border border-red-500/30"
                          : "bg-[#1a1a1a] text-gray-400 border border-[#2a2a2a] hover:border-gray-600"
                      }`}
                    >
                      {allergy}
                    </button>
                  ))}
                </div>
              </div>

              {/* Weight Pace (only if lose or gain) */}
              {(formData.primaryGoal === "lose_weight" || formData.primaryGoal === "gain_muscle") && (
                <div className="mb-5">
                  <label className="block text-gray-400 text-sm mb-3">
                    Weight pace: {formData.weightPace} kg/week
                  </label>
                  <input
                    type="range"
                    min="0.25"
                    max="1"
                    step="0.25"
                    value={formData.weightPace}
                    onChange={(e) => updateField("weightPace", parseFloat(e.target.value))}
                    className="w-full accent-[#22c55e]"
                  />
                  <div className="flex justify-between text-xs text-gray-600 mt-1">
                    <span>Slow</span>
                    <span>Moderate</span>
                    <span>Aggressive</span>
                  </div>
                </div>
              )}

              <div className="flex gap-3">
                <button
                  onClick={handleBack}
                  disabled={isLoading}
                  className="flex-1 py-3.5 rounded-xl bg-[#1a1a1a] text-white font-medium hover:bg-[#222222] active:scale-[0.98] transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  <ArrowLeft className="w-4 h-4" /> Back
                </button>
                <button
                  onClick={handleFinalSubmit}
                  disabled={isLoading || !formData.primaryGoal}
                  className="flex-1 py-3.5 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {isLoading ? (
                    <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                  ) : (
                    <>Complete Setup <ArrowRight className="w-4 h-4" /></>
                  )}
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Login Link */}
        <p className="text-center text-gray-500 text-sm mt-6">
          Already have an account?{" "}
          <a href="/login" className="text-[#22c55e] hover:underline font-medium">
            Sign in
          </a>
        </p>
      </div>
    </motion.div>
  );
}