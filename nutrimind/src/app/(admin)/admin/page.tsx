"use client";

import { useState, useEffect } from "react";
import { Users, UserCheck, Utensils, MessageSquare, TrendingUp } from "lucide-react";

interface User {
  id: string;
  name: string;
  email: string;
  is_active: boolean;
  primary_goal?: string;
  created_at: string;
}

export default function AdminOverviewPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const token = typeof window !== "undefined" ? localStorage.getItem("nutrimind_token") : null;
  const API = process.env.NEXT_PUBLIC_API_URL ;

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const res = await fetch(`${API}/api/v1/users/admin/users`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          const data = await res.json();
          setUsers(data);
        }
      } catch (error) {
        console.error("Failed to fetch users:", error);
      } finally {
        setIsLoading(false);
      }
    };
    fetchUsers();
  }, []);

  const totalUsers = users.length;
  const activeUsers = users.filter((u) => u.is_active).length;

  const kpis = [
    {
      label: "Total Users",
      value: totalUsers,
      icon: Users,
      color: "text-blue-400",
      bg: "bg-blue-500/10",
    },
    {
      label: "Active Today",
      value: activeUsers,
      icon: UserCheck,
      color: "text-green-400",
      bg: "bg-green-500/10",
    },
    {
      label: "Meals Logged",
      value: 142,
      icon: Utensils,
      color: "text-orange-400",
      bg: "bg-orange-500/10",
    },
    {
      label: "AI Messages",
      value: 89,
      icon: MessageSquare,
      color: "text-purple-400",
      bg: "bg-purple-500/10",
    },
  ];

  const goalColors: Record<string, string> = {
    lose_weight: "bg-red-500/20 text-red-400 border border-red-500/30",
    maintain: "bg-blue-500/20 text-blue-400 border border-blue-500/30",
    gain_muscle: "bg-purple-500/20 text-purple-400 border border-purple-500/30",
    eat_healthier: "bg-green-500/20 text-green-400 border border-green-500/30",
  };

  const formatGoal = (goal: string) => {
    return goal
      .split("_")
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(" ");
  };

  const formatDate = (dateStr: string) => {
    if (!dateStr) return "—";
    return new Date(dateStr).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  const recentUsers = users.slice(0, 10);

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white">Admin Overview</h1>
          <p className="text-gray-500 text-sm mt-1">Monitor your platform metrics</p>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 bg-red-500/10 rounded-xl border border-red-500/30">
          <TrendingUp className="w-4 h-4 text-red-400" />
          <span className="text-red-400 text-sm font-medium">Live Data</span>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {kpis.map((kpi) => (
          <div
            key={kpi.label}
            className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 relative overflow-hidden"
          >
            <div className={`absolute top-4 right-4 w-12 h-12 rounded-xl ${kpi.bg} flex items-center justify-center`}>
              <kpi.icon className={`w-6 h-6 ${kpi.color}`} />
            </div>
            <div className="relative z-10">
              <p className="text-4xl font-bold text-white mt-8">{kpi.value}</p>
              <p className="text-gray-500 text-sm mt-1">{kpi.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Recent Users Table */}
      <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
        <h2 className="text-white font-semibold mb-4">Recent Registrations</h2>

        {isLoading ? (
          <div className="animate-pulse space-y-3">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="h-12 bg-[#1a1a1a] rounded-xl" />
            ))}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-gray-500 text-sm border-b border-[#1a1a1a]">
                  <th className="pb-3 font-medium">User</th>
                  <th className="pb-3 font-medium">Email</th>
                  <th className="pb-3 font-medium">Goal</th>
                  <th className="pb-3 font-medium">Joined</th>
                  <th className="pb-3 font-medium">Status</th>
                </tr>
              </thead>
              <tbody>
                {recentUsers.map((user) => (
                  <tr
                    key={user.id}
                    className="border-b border-[#1a1a1a]/50 hover:bg-[#1a1a1a]/50 transition-colors"
                  >
                    <td className="py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#22c55e] flex items-center justify-center">
                          <span className="text-black text-sm font-bold">
                            {user.name?.charAt(0)?.toUpperCase() || "U"}
                          </span>
                        </div>
                        <span className="text-white font-medium">{user.name || "—"}</span>
                      </div>
                    </td>
                    <td className="py-4 text-gray-400 text-sm">{user.email || "—"}</td>
                    <td className="py-4">
                      {user.primary_goal && (
                        <span
                          className={`px-2.5 py-1 rounded-full text-xs font-medium ${
                            goalColors[user.primary_goal] || "bg-gray-500/20 text-gray-400"
                          }`}
                        >
                          {formatGoal(user.primary_goal)}
                        </span>
                      )}
                    </td>
                    <td className="py-4 text-gray-400 text-sm">{formatDate(user.created_at)}</td>
                    <td className="py-4">
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
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}