"use client";

import { useState, useEffect } from "react";
import { Search, Filter, X, ChevronRight, User as UserIcon } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

interface User {
  id: string;
  name: string;
  email: string;
  phone?: string;
  is_active: boolean;
  primary_goal?: string;
  onboarding_step?: number;
  created_at: string;
  height?: number;
  current_weight?: number;
  daily_cal_target?: number;
  activity_level?: string;
}

const goalColors: Record<string, string> = {
  lose_weight: "bg-red-500/20 text-red-400 border border-red-500/30",
  maintain: "bg-blue-500/20 text-blue-400 border border-blue-500/30",
  gain_muscle: "bg-purple-500/20 text-purple-400 border border-purple-500/30",
  eat_healthier: "bg-green-500/20 text-green-400 border border-green-500/30",
};

const goalLabels: Record<string, string> = {
  lose_weight: "Lose Weight",
  maintain: "Maintain",
  gain_muscle: "Gain Muscle",
  eat_healthier: "Eat Healthier",
};

const activityLabels: Record<string, string> = {
  sedentary: "Sedentary",
  lightly_active: "Lightly Active",
  moderately_active: "Moderately Active",
  very_active: "Very Active",
  extra_active: "Extra Active",
};

export default function AdminUsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<"all" | "active" | "suspended">("all");
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [showPanel, setShowPanel] = useState(false);

  const token = typeof window !== "undefined" ? localStorage.getItem("nutrimind_token") : null;
  const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const res = await fetch(`${API}/api/v1/users/admin/users`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          setUsers(await res.json());
        }
      } catch (error) {
        console.error("Failed to fetch users:", error);
      } finally {
        setIsLoading(false);
      }
    };
    fetchUsers();
  }, []);

  const formatDate = (dateStr: string) => {
    if (!dateStr) return "—";
    return new Date(dateStr).toLocaleDateString("en-US", {
      month: "long",
      day: "numeric",
      year: "numeric",
    });
  };

  const filteredUsers = users.filter((user) => {
    const matchesSearch =
      user.name?.toLowerCase().includes(search.toLowerCase()) ||
      user.email?.toLowerCase().includes(search.toLowerCase());
    const matchesFilter =
      filter === "all" ||
      (filter === "active" && user.is_active) ||
      (filter === "suspended" && !user.is_active);
    return matchesSearch && matchesFilter;
  });

  const toggleUserStatus = async (user: User) => {
    try {
      const res = await fetch(`${API}/api/v1/users/admin/users/${user.id}?is_active=${!user.is_active}`, {
        method: "PUT",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setUsers((prev) =>
          prev.map((u) => (u.id === user.id ? { ...u, is_active: !u.is_active } : u))
        );
        if (selectedUser?.id === user.id) {
          setSelectedUser({ ...selectedUser, is_active: !selectedUser.is_active });
        }
      }
    } catch (error) {
      console.error("Failed to toggle user status:", error);
    }
  };

  const deleteUser = async (userId: string) => {
    if (!confirm("Are you sure you want to delete this user? This action cannot be undone.")) {
      return;
    }
    try {
      const res = await fetch(`${API}/api/v1/users/admin/users/${userId}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setUsers((prev) => prev.filter((u) => u.id !== userId));
        setShowPanel(false);
        setSelectedUser(null);
      }
    } catch (error) {
      console.error("Failed to delete user:", error);
    }
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white">User Management</h1>
          <p className="text-gray-500 text-sm mt-1">{users.length} total users</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col md:flex-row gap-4 mb-6">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
          <input
            type="text"
            placeholder="Search by name or email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-3 bg-[#111111] border border-[#1a1a1a] rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
          />
        </div>
        <div className="flex gap-2">
          {(["all", "active", "suspended"] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
                filter === f
                  ? "bg-[#22c55e] text-black"
                  : "bg-[#111111] text-gray-400 hover:bg-[#1a1a1a]"
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl overflow-hidden">
        {isLoading ? (
          <div className="p-6 animate-pulse space-y-3">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="h-16 bg-[#1a1a1a] rounded-xl" />
            ))}
          </div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="text-left text-gray-500 text-sm border-b border-[#1a1a1a]">
                <th className="p-4 font-medium">User</th>
                <th className="p-4 font-medium">Goal</th>
                <th className="p-4 font-medium">Joined</th>
                <th className="p-4 font-medium">Onboarding</th>
                <th className="p-4 font-medium">Status</th>
                <th className="p-4 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((user) => (
                <tr
                  key={user.id}
                  className="border-b border-[#1a1a1a]/50 hover:bg-[#1a1a1a]/50 transition-colors"
                >
                  <td className="p-4">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-full bg-[#22c55e] flex items-center justify-center">
                        <span className="text-black text-sm font-bold">
                          {user.name?.charAt(0)?.toUpperCase() || "U"}
                        </span>
                      </div>
                      <div>
                        <p className="text-white font-medium">{user.name || "—"}</p>
                        <p className="text-gray-500 text-xs">{user.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="p-4">
                    {user.primary_goal && (
                      <span
                        className={`px-2.5 py-1 rounded-full text-xs font-medium ${
                          goalColors[user.primary_goal] || "bg-gray-500/20 text-gray-400"
                        }`}
                      >
                        {goalLabels[user.primary_goal] || user.primary_goal}
                      </span>
                    )}
                  </td>
                  <td className="p-4 text-gray-400 text-sm">{formatDate(user.created_at)}</td>
                  <td className="p-4">
                    {user.onboarding_step === 4 ? (
                      <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-green-500/20 text-green-400 border border-green-500/30">
                        Complete
                      </span>
                    ) : (
                      <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-yellow-500/20 text-yellow-400 border border-yellow-500/30">
                        Step {user.onboarding_step || 0}
                      </span>
                    )}
                  </td>
                  <td className="p-4">
                    <span
                      className={`px-2.5 py-1 rounded-full text-xs font-medium ${
                        user.is_active
                          ? "bg-green-500/20 text-green-400 border border-green-500/30"
                          : "bg-red-500/20 text-red-400 border border-red-500/30"
                      }`}
                    >
                      {user.is_active ? "Active" : "Suspended"}
                    </span>
                  </td>
                  <td className="p-4">
                    <button
                      onClick={() => {
                        setSelectedUser(user);
                        setShowPanel(true);
                      }}
                      className="flex items-center gap-1 text-gray-400 hover:text-white transition-colors text-sm"
                    >
                      View <ChevronRight className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Slide-over Panel */}
      <AnimatePresence>
        {showPanel && selectedUser && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50"
              onClick={() => setShowPanel(false)}
            />
            <motion.div
              initial={{ x: "100%" }}
              animate={{ x: 0 }}
              exit={{ x: "100%" }}
              transition={{ type: "spring", damping: 25, stiffness: 200 }}
              className="fixed right-0 top-0 bottom-0 w-full max-w-md bg-[#0d0d0d] border-l border-[#1a1a1a] z-50 overflow-y-auto"
            >
              <div className="p-6">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-xl font-bold text-white">User Details</h2>
                  <button
                    onClick={() => setShowPanel(false)}
                    className="p-2 text-gray-400 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
                  >
                    <X className="w-5 h-5" />
                  </button>
                </div>

                {/* User Header */}
                <div className="flex items-center gap-4 mb-6 p-4 bg-[#111111] rounded-xl">
                  <div className="w-16 h-16 rounded-full bg-[#22c55e] flex items-center justify-center">
                    <span className="text-black text-2xl font-bold">
                      {selectedUser.name?.charAt(0)?.toUpperCase() || "U"}
                    </span>
                  </div>
                  <div>
                    <p className="text-white font-semibold text-lg">{selectedUser.name || "—"}</p>
                    <p className="text-gray-500 text-sm">{selectedUser.email}</p>
                  </div>
                </div>

                {/* Profile Details */}
                <div className="space-y-4">
                  <div className="p-4 bg-[#111111] rounded-xl">
                    <h3 className="text-gray-400 text-xs uppercase mb-3">Contact</h3>
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Email</span>
                        <span className="text-white">{selectedUser.email || "—"}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Phone</span>
                        <span className="text-white">{selectedUser.phone || "—"}</span>
                      </div>
                    </div>
                  </div>

                  <div className="p-4 bg-[#111111] rounded-xl">
                    <h3 className="text-gray-400 text-xs uppercase mb-3">Goals</h3>
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Primary Goal</span>
                        <span
                          className={`px-2 py-1 rounded-full text-xs ${
                            goalColors[selectedUser.primary_goal || ""] || "bg-gray-500/20 text-gray-400"
                          }`}
                        >
                          {goalLabels[selectedUser.primary_goal || ""] || "—"}
                        </span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Activity Level</span>
                        <span className="text-white">
                          {activityLabels[selectedUser.activity_level || ""] || "—"}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="p-4 bg-[#111111] rounded-xl">
                    <h3 className="text-gray-400 text-xs uppercase mb-3">Measurements</h3>
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Height</span>
                        <span className="text-white">{selectedUser.height ? `${selectedUser.height} cm` : "—"}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Current Weight</span>
                        <span className="text-white">{selectedUser.current_weight ? `${selectedUser.current_weight} kg` : "—"}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Daily Cal Target</span>
                        <span className="text-white">{selectedUser.daily_cal_target ? `${selectedUser.daily_cal_target} kcal` : "—"}</span>
                      </div>
                    </div>
                  </div>

                  <div className="p-4 bg-[#111111] rounded-xl">
                    <h3 className="text-gray-400 text-xs uppercase mb-3">Account</h3>
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Joined</span>
                        <span className="text-white">{formatDate(selectedUser.created_at)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Onboarding</span>
                        <span className="text-white">
                          {selectedUser.onboarding_step === 4 ? "Complete" : `Step ${selectedUser.onboarding_step || 0}`}
                        </span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Status</span>
                        <span
                          className={`px-2 py-1 rounded-full text-xs ${
                            selectedUser.is_active
                              ? "bg-green-500/20 text-green-400"
                              : "bg-red-500/20 text-red-400"
                          }`}
                        >
                          {selectedUser.is_active ? "Active" : "Suspended"}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Actions */}
                <div className="mt-6 space-y-3">
                  <button
                    onClick={() => toggleUserStatus(selectedUser)}
                    className={`w-full py-3 rounded-xl font-medium transition-all ${
                      selectedUser.is_active
                        ? "bg-red-500/20 text-red-400 hover:bg-red-500/30 border border-red-500/30"
                        : "bg-green-500/20 text-green-400 hover:bg-green-500/30 border border-green-500/30"
                    }`}
                  >
                    {selectedUser.is_active ? "Suspend User" : "Activate User"}
                  </button>
                  <button
                    onClick={() => deleteUser(selectedUser.id)}
                    className="w-full py-3 rounded-xl bg-red-500/10 text-red-400 hover:bg-red-500/20 border border-red-500/30 font-medium transition-all"
                  >
                    Delete User
                  </button>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}