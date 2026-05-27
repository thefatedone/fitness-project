import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "NutriMind",
  description: "AI-powered fitness and nutrition assistant",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-full flex flex-col antialiased">{children}</body>
    </html>
  );
}