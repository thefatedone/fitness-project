"use client";
import { useState } from "react";
import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { Mail, Phone, Lock, Eye, EyeOff, ArrowRight } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const [loginMethod, setLoginMethod] = useState<"email" | "phone">("email");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
      const res = await fetch(`${apiUrl}/api/v1/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          [loginMethod]: identifier,
          password,
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        setError(data.detail || "Invalid credentials");
        return;
      }

      localStorage.setItem("nutrimind_token", data.access_token);
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
      className="w-full max-w-md"
    >
      <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-8">
        {/* Logo */}
        <div className="flex items-center justify-center gap-2 mb-8">
          <div className="w-10 h-10 rounded-xl bg-[#22c55e] flex items-center justify-center">
            <span className="text-black font-bold text-xl">N</span>
          </div>
          <span className="text-white font-bold text-xl">NutriMind</span>
        </div>

        <h2 className="text-2xl font-bold text-white text-center mb-2">Welcome back</h2>
        <p className="text-gray-500 text-sm text-center mb-8">Sign in to continue your journey</p>

        {error && (
          <div className="mb-6 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Email/Phone Toggle */}
          <div className="flex rounded-xl bg-[#1a1a1a] p-1">
            <button
              type="button"
              onClick={() => setLoginMethod("email")}
              className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all duration-300 ${
                loginMethod === "email"
                  ? "bg-[#22c55e] text-black"
                  : "text-gray-400 hover:text-white"
              }`}
            >
              Email
            </button>
            <button
              type="button"
              onClick={() => setLoginMethod("phone")}
              className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all duration-300 ${
                loginMethod === "phone"
                  ? "bg-[#22c55e] text-black"
                  : "text-gray-400 hover:text-white"
              }`}
            >
              Phone
            </button>
          </div>

          {/* Identifier Input */}
          <div className="relative">
            {loginMethod === "email" ? (
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
            ) : (
              <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
            )}
            <input
              type={loginMethod === "email" ? "email" : "tel"}
              placeholder={loginMethod === "email" ? "Email address" : "Phone number"}
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              className="w-full pl-12 pr-4 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all duration-300"
              required
            />
          </div>

          {/* Password Input */}
          <div className="relative">
            <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
            <input
              type={showPassword ? "text" : "password"}
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full pl-12 pr-12 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all duration-300"
              required
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-white transition-colors"
            >
              {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
            </button>
          </div>

          {/* Forgot Password */}
          <div className="text-right">
            <a href="#" className="text-sm text-gray-500 hover:text-[#22c55e] transition-colors">
              Forgot password?
            </a>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={isLoading}
            className="w-full py-3.5 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all duration-300 disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {isLoading ? (
              <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
            ) : (
              <>
                Sign In
                <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>
        </form>

        {/* Divider */}
        <div className="flex items-center gap-4 my-8">
          <div className="flex-1 h-px bg-[#2a2a2a]" />
          <span className="text-gray-600 text-sm">or</span>
          <div className="flex-1 h-px bg-[#2a2a2a]" />
        </div>

        {/* Register Link */}
        <p className="text-center text-gray-500 text-sm">
          Don&apos;t have an account?{" "}
          <a href="/register" className="text-[#22c55e] hover:underline font-medium">
            Start Free
          </a>
        </p>
      </div>
    </motion.div>
  );
}