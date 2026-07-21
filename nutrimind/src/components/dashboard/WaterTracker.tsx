"use client";

import { useState, useEffect } from "react";
import { Droplet, Plus, X, Trash2 } from "lucide-react";

interface WaterLog {
  id: string;
  user_id: string;
  amount: number; // ml
  date: string;
  created_at: string;
}

interface WaterTrackerProps {
  /** ISO date string (YYYY-MM-DD) for the day to display */
  date: string;
}

const MIN_LITRES = 0.1;
const MAX_LITRES = 10;
const QUICK_PICKS_LITRES = [0.2, 0.5, 1, 2] as const;

function mlToLitres(ml: number): number {
  return ml / 1000;
}
function litresToMl(litres: number): number {
  return Math.round(litres * 1000);
}
function formatAmount(ml: number): string {
  // Whole litres render as "X L"; everything else as ml.
  if (ml > 0 && ml % 1000 === 0) return `${ml / 1000} L`;
  if (ml >= 1000) return `${(ml / 1000).toFixed(1)} L`;
  return `${ml} ml`;
}

export default function WaterTracker({ date }: WaterTrackerProps) {
  const [logs, setLogs] = useState<WaterLog[]>([]);
  const [userWeight, setUserWeight] = useState<number | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [amountInput, setAmountInput] = useState("0.5");
  const [isSaving, setIsSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [isLoadingLogs, setIsLoadingLogs] = useState(true);

  // --- Data fetch -------------------------------------------------------------
  const fetchLogs = async () => {
    setIsLoadingLogs(true);
    try {
      const token = localStorage.getItem("nutrimind_token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      const res = await fetch(
        `${apiUrl}/api/v1/tracker/water?date_str=${date}`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      if (res.ok) {
        const data: WaterLog[] = await res.json();
        setLogs(data);
      } else {
        console.error("Failed to load water logs:", res.status);
      }
    } catch (err) {
      console.error("Failed to load water logs:", err);
    } finally {
      setIsLoadingLogs(false);
    }
  };

  useEffect(() => {
    fetchLogs();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [date]);

  // Daily goal: ~35 ml per kg of bodyweight, default 2 L if weight unknown
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
          if (data.current_weight) setUserWeight(data.current_weight);
        }
      } catch {
        /* ignore */
      }
    };
    fetchUserWeight();
  }, []);

  // --- Derived state ----------------------------------------------------------
  const totalMl = logs.reduce((sum, log) => sum + (log.amount || 0), 0);
  const dailyGoal = userWeight ? Math.round(userWeight * 35) : 2000;
  const progress = Math.min((totalMl / dailyGoal) * 100, 100);
  const remaining = Math.max(dailyGoal - totalMl, 0);

  const parsedLitres = parseFloat(amountInput);
  const isValid =
    !Number.isNaN(parsedLitres) &&
    parsedLitres >= MIN_LITRES &&
    parsedLitres <= MAX_LITRES;

  // --- Handlers ---------------------------------------------------------------
  const openModal = () => {
    setAmountInput("0.5");
    setError("");
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!isValid) {
      setError(`Enter between ${MIN_LITRES} and ${MAX_LITRES} L`);
      return;
    }
    setIsSaving(true);
    setError("");
    try {
      const token = localStorage.getItem("nutrimind_token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      const ml = litresToMl(parsedLitres);
      const res = await fetch(`${apiUrl}/api/v1/tracker/water`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ amount: ml, date }),
      });
      if (res.ok) {
        setShowModal(false);
        await fetchLogs();
      } else {
        const errBody = await res.json().catch(() => ({}));
        setError(errBody.detail || "Failed to add water");
      }
    } catch (err) {
      console.error("Failed to add water:", err);
      setError("Network error");
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    try {
      const token = localStorage.getItem("nutrimind_token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      const res = await fetch(`${apiUrl}/api/v1/tracker/water/${id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setLogs((prev) => prev.filter((l) => l.id !== id));
      } else {
        console.error("Failed to delete water log:", res.status);
      }
    } catch (err) {
      console.error("Failed to delete water log:", err);
    } finally {
      setDeletingId(null);
    }
  };

  // --- Render -----------------------------------------------------------------
  return (
    <>
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <span className="text-gray-400 text-sm font-medium">Water Intake</span>
          <div className="flex items-center gap-2">
            <span className="text-white text-sm font-medium">{formatAmount(totalMl)}</span>
            <span className="text-gray-500 text-xs">/ {formatAmount(dailyGoal)}</span>
          </div>
        </div>

        <div className="h-2 bg-[#1a1a1a] rounded-full overflow-hidden">
          <div
            className="h-full bg-blue-500 rounded-full transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>

        <div className="flex items-center justify-between text-xs">
          <span className="text-gray-500">{Math.round(progress)}% of daily goal</span>
          <span className="text-gray-500">{formatAmount(remaining)} remaining</span>
        </div>

        <button
          onClick={openModal}
          className="w-full flex items-center justify-center gap-2 py-2.5 bg-[#22c55e] text-black font-semibold rounded-xl hover:bg-[#16a34a] active:scale-[0.98] transition-all"
        >
          <Plus className="w-4 h-4" />
          Add Water
        </button>

        {/* Today's entries */}
        {isLoadingLogs ? (
          <div className="h-8 bg-[#1a1a1a] rounded-lg animate-pulse" />
        ) : logs.length > 0 ? (
          <div className="space-y-2 pt-1">
            <div className="text-gray-500 text-[10px] uppercase tracking-wider">
              Today&apos;s entries
            </div>
            {logs.map((log) => (
              <div
                key={log.id}
                className="flex items-center justify-between bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg px-3 py-2"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <Droplet className="w-4 h-4 text-blue-400 flex-shrink-0" />
                  <span className="text-white text-sm font-medium">{formatAmount(log.amount)}</span>
                  <span className="text-gray-500 text-xs">
                    {new Date(log.created_at).toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </span>
                </div>
                <button
                  onClick={() => handleDelete(log.id)}
                  disabled={deletingId === log.id}
                  aria-label={`Delete ${formatAmount(log.amount)} entry`}
                  className="p-1.5 text-gray-500 hover:text-red-400 hover:bg-red-500/10 rounded transition-colors flex-shrink-0 disabled:opacity-40"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            ))}
          </div>
        ) : null}
      </div>

      {/* Add Water Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 w-full max-w-md">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-white font-semibold flex items-center gap-2">
                <Droplet className="w-5 h-5 text-blue-400" />
                Add Water
              </h3>
              <button
                onClick={() => setShowModal(false)}
                aria-label="Close"
                className="p-2 text-gray-400 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <label htmlFor="water-amount" className="text-gray-400 text-sm mb-2 block">
              How much did you drink?
            </label>
            <div className="relative">
              <input
                id="water-amount"
                type="number"
                inputMode="decimal"
                step="0.1"
                min={MIN_LITRES}
                max={MAX_LITRES}
                value={amountInput}
                onChange={(e) => {
                  setAmountInput(e.target.value);
                  setError("");
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && isValid && !isSaving) handleSave();
                }}
                autoFocus
                className="w-full pl-4 pr-10 py-3 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl text-white text-lg font-medium focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500/20 transition-all"
              />
              <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 text-sm pointer-events-none">
                L
              </span>
            </div>
            <p className="text-gray-500 text-xs mt-2">
              {isValid
                ? `= ${litresToMl(parsedLitres)} ml`
                : `Enter between ${MIN_LITRES} and ${MAX_LITRES} L`}
            </p>

            <p className="text-gray-400 text-sm mt-5 mb-2">Quick add</p>
            <div className="grid grid-cols-4 gap-2">
              {QUICK_PICKS_LITRES.map((l) => {
                const active = parseFloat(amountInput) === l;
                return (
                  <button
                    key={l}
                    type="button"
                    onClick={() => {
                      setAmountInput(String(l));
                      setError("");
                    }}
                    className={`py-2.5 rounded-xl font-medium transition-all ${
                      active
                        ? "bg-[#22c55e] text-black"
                        : "bg-[#1a1a1a] text-white border border-[#2a2a2a] hover:border-green-500/50"
                    }`}
                  >
                    {l} L
                  </button>
                );
              })}
            </div>

            {error && <p className="text-red-400 text-sm mt-3">{error}</p>}

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowModal(false)}
                disabled={isSaving}
                className="flex-1 py-3 rounded-xl bg-[#1a1a1a] text-white font-medium hover:bg-[#222222] active:scale-[0.98] transition-all disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={!isValid || isSaving}
                className="flex-1 py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all flex items-center justify-center gap-2 disabled:opacity-50"
              >
                {isSaving ? (
                  <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                ) : (
                  "Add"
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}