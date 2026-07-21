"use client";

import { useState, KeyboardEvent, ClipboardEvent } from "react";
import { X } from "lucide-react";

interface TagInputProps {
  value: string[];
  onChange: (value: string[]) => void;
  placeholder?: string;
  disabled?: boolean;
}

/**
 * Unlimited, free-text tag input shared by registration and profile.
 * - Type + Enter (or comma) to add a chip
 * - Paste "a, b, c" to add multiple at once
 * - Click the X on a chip to remove it
 * - Backspace on empty input removes the last chip
 * - Trims, dedupes case-insensitively, ignores blanks
 */
export function TagInput({
  value,
  onChange,
  placeholder = "Type and press Enter…",
  disabled = false,
}: TagInputProps) {
  const [input, setInput] = useState("");

  const addItems = (raw: string) => {
    const items = raw
      .split(/[,\n]/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    setInput("");
    if (items.length === 0) return;
    const seen = new Set(value.map((v) => v.toLowerCase()));
    const next = [...value];
    for (const item of items) {
      const key = item.toLowerCase();
      if (!seen.has(key)) {
        seen.add(key);
        next.push(item);
      }
    }
    if (next.length !== value.length) onChange(next);
  };

  const removeAt = (index: number) => {
    onChange(value.filter((_, i) => i !== index));
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      e.preventDefault();
      if (input.trim()) addItems(input);
    } else if (e.key === ",") {
      e.preventDefault();
      if (input.trim()) addItems(input);
    } else if (e.key === "Backspace" && input === "" && value.length > 0) {
      onChange(value.slice(0, -1));
    }
  };

  const handlePaste = (e: ClipboardEvent<HTMLInputElement>) => {
    const pasted = e.clipboardData.getData("text");
    if (/[,\n]/.test(pasted)) {
      e.preventDefault();
      addItems(pasted);
    }
  };

  return (
    <div className="w-full">
      <div className="flex flex-wrap gap-2 p-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl focus-within:border-green-500 focus-within:ring-1 focus-within:ring-green-500/20 transition-all min-h-[44px]">
        {value.map((tag, i) => (
          <span
            key={`${tag}-${i}`}
            className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[#22c55e]/15 text-[#22c55e] text-sm border border-[#22c55e]/30"
          >
            {tag}
            {!disabled && (
              <button
                type="button"
                onClick={() => removeAt(i)}
                aria-label={`Remove ${tag}`}
                className="hover:bg-[#22c55e]/25 rounded-full p-0.5 transition-colors"
              >
                <X className="w-3 h-3" />
              </button>
            )}
          </span>
        ))}
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          onPaste={handlePaste}
          onBlur={() => {
            if (input.trim()) addItems(input);
          }}
          placeholder={value.length === 0 ? placeholder : ""}
          disabled={disabled}
          className="flex-1 min-w-[120px] bg-transparent text-white placeholder-gray-600 focus:outline-none text-sm"
        />
      </div>
    </div>
  );
}

export default TagInput;
