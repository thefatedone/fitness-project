"use client";

import { useState, useEffect } from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
} from "recharts";
import { TrendingUp, Target, Activity } from "lucide-react";

interface User {
  primary_goal?: string;
  activity_level?: string;
  created_at?: string;
}

export default function AdminAnalyticsPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);

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

  // Process data for charts
  const goalCounts = users.reduce(
    (acc, user) => {
      const goal = user.primary_goal || "unknown";
      acc[goal] = (acc[goal] || 0) + 1;
      return acc;
    },
    {} as Record<string, number>
  );

  const goalDistribution = [
    { name: "Lose Weight", value: goalCounts["lose_weight"] || 0, color: "#ef4444" },
    { name: "Maintain", value: goalCounts["maintain"] || 0, color: "#3b82f6" },
    { name: "Gain Muscle", value: goalCounts["gain_muscle"] || 0, color: "#a855f7" },
    { name: "Eat Healthier", value: goalCounts["eat_healthier"] || 0, color: "#22c55e" },
  ].filter((d) => d.value > 0);

  const activityCounts = users.reduce(
    (acc, user) => {
      const level = user.activity_level || "unknown";
      acc[level] = (acc[level] || 0) + 1;
      return acc;
    },
    {} as Record<string, number>
  );

  const activityDistribution = [
    { level: "Sedentary", count: activityCounts["sedentary"] || 0 },
    { level: "Lightly Active", count: activityCounts["lightly_active"] || 0 },
    { level: "Moderately Active", count: activityCounts["moderately_active"] || 0 },
    { level: "Very Active", count: activityCounts["very_active"] || 0 },
    { level: "Extra Active", count: activityCounts["extra_active"] || 0 },
  ];

  // User growth chart - last 7 days
  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const date = new Date();
    date.setDate(date.getDate() - (6 - i));
    return date.toISOString().split("T")[0];
  });

  const userGrowth = last7Days.map((date) => {
    const count = users.filter((u) => {
      if (!u.created_at) return false;
      return u.created_at.split("T")[0] <= date;
    }).length;
    return { date, count };
  });

  const formatDateLabel = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="h-8 bg-[#1a1a1a] rounded w-48 animate-pulse" />
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-80 bg-[#1a1a1a] rounded-2xl animate-pulse" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Analytics</h1>
        <p className="text-gray-500 text-sm mt-1">Platform insights and user metrics</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* User Growth Chart */}
        <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="w-10 h-10 rounded-xl bg-green-500/10 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-green-400" />
            </div>
            <div>
              <h2 className="text-white font-semibold">User Growth</h2>
              <p className="text-gray-500 text-xs">Cumulative users over time</p>
            </div>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={userGrowth}>
                <XAxis
                  dataKey="date"
                  stroke="#666"
                  fontSize={10}
                  tickFormatter={(v) => formatDateLabel(v)}
                />
                <YAxis stroke="#666" fontSize={10} />
                <Tooltip
                  contentStyle={{
                    background: "#1a1a1a",
                    border: "1px solid #333",
                    borderRadius: "8px",
                  }}
                  labelFormatter={(v) => formatDateLabel(v as string)}
                  labelStyle={{ color: "#999" }}
                />
                <Line
                  type="monotone"
                  dataKey="count"
                  stroke="#22c55e"
                  strokeWidth={2}
                  dot={{ fill: "#22c55e", strokeWidth: 0 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Goal Distribution Pie Chart */}
        <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
              <Target className="w-5 h-5 text-purple-400" />
            </div>
            <div>
              <h2 className="text-white font-semibold">Goal Distribution</h2>
              <p className="text-gray-500 text-xs">User goals breakdown</p>
            </div>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={goalDistribution}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={90}
                  paddingAngle={2}
                  dataKey="value"
                >
                  {goalDistribution.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    background: "#1a1a1a",
                    border: "1px solid #333",
                    borderRadius: "8px",
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="flex flex-wrap justify-center gap-4 mt-4">
            {goalDistribution.map((item) => (
              <div key={item.name} className="flex items-center gap-2">
                <div
                  className="w-3 h-3 rounded-full"
                  style={{ backgroundColor: item.color }}
                />
                <span className="text-gray-400 text-xs">
                  {item.name} ({item.value})
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Activity Level Bar Chart */}
        <div className="bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 lg:col-span-2">
          <div className="flex items-center gap-2 mb-6">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
              <Activity className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <h2 className="text-white font-semibold">Activity Level Distribution</h2>
              <p className="text-gray-500 text-xs">User activity preferences</p>
            </div>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={activityDistribution}>
                <XAxis dataKey="level" stroke="#666" fontSize={10} />
                <YAxis stroke="#666" fontSize={10} />
                <Tooltip
                  contentStyle={{
                    background: "#1a1a1a",
                    border: "1px solid #333",
                    borderRadius: "8px",
                  }}
                />
                <Bar dataKey="count" fill="#22c55e" radius={[8, 8, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}