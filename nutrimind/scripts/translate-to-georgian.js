#!/usr/bin/env node
/**
 * translate-to-georgian.js
 *
 * Translates src/i18n/locales/en/translation.json to Georgian using MiniMax Text-01 API
 * and saves the result to src/i18n/locales/ka/translation.json.
 *
 * Usage:
 *   node scripts/translate-to-georgian.js
 *
 * Environment:
 *   MINIMAX_API_KEY   — your MiniMax API key
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const SOURCE_FILE = path.join(ROOT, "src/i18n/locales/en/translation.json");
const TARGET_FILE = path.join(ROOT, "src/i18n/locales/ka/translation.json");
const API_ENDPOINT = "https://api.minimax.chat/v1/text/chatcompletion_v2";
const MODEL = "MiniMax-Text-01";

const SYSTEM_PROMPT = `You are a professional translator specializing in English to Georgian (ქართული) translation.
You are translating a nutrition tracking app called NutriMind. Translate naturally and concisely.
Preserve any placeholders like {{value}}, {{unit}}, %s, {{percent}}, {{remaining}}, {{kcal}}, {{target}}.
Return ONLY valid JSON, no explanation, no markdown.`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Flattens a nested JSON object into an array of { keyPath, value } entries.
 * e.g. { nav: { tracker: "Tracker" } } → [{ keyPath: "nav.tracker", value: "Tracker" }]
 */
function flatten(obj, prefix = "") {
  const entries = [];
  for (const [key, val] of Object.entries(obj)) {
    const fullKey = prefix ? `${prefix}.${key}` : key;
    if (val && typeof val === "object" && !Array.isArray(val)) {
      entries.push(...flatten(val, fullKey));
    } else {
      entries.push({ keyPath: fullKey, value: String(val) });
    }
  }
  return entries;
}

/**
 * Reassembles a flat array of { keyPath, value } entries back into a nested object.
 */
function unflatten(entries) {
  const result = {};
  for (const { keyPath, value } of entries) {
    const keys = keyPath.split(".");
    let current = result;
    for (let i = 0; i < keys.length - 1; i++) {
      if (!(keys[i] in current)) current[keys[i]] = {};
      current = current[keys[i]];
    }
    current[keys[keys.length - 1]] = value;
  }
  return result;
}

/**
 * Calls the MiniMax ChatCompletion v2 API.
 */
async function translateWithMiniMax(text) {
  const apiKey = process.env.MINIMAX_API_KEY;
  if (!apiKey) {
    throw new Error("MINIMAX_API_KEY environment variable is not set.");
  }

  console.log("  Calling MiniMax API…");
  const response = await fetch(API_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content:
            "Translate all values in this JSON from English to Georgian. Return only the translated JSON:\n" +
            text,
        },
      ],
      temperature: 0.3,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`MiniMax API error ${response.status}: ${body}`);
  }

  const data = await response.json();

  const choice = data?.choices?.[0];
  if (!choice) {
    throw new Error("MiniMax response missing choices: " + JSON.stringify(data));
  }

  const raw = choice?.message?.content ?? "";
  return raw;
}

/**
 * Strips any markdown code fences (```json ... ```) that the model might return.
 */
function stripMarkdown(raw) {
  return raw
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("\n=== MiniMax Georgian Translation Script ===\n");

  // 1. Read source
  console.log(`[1] Reading: ${path.relative(ROOT, SOURCE_FILE)}`);
  if (!fs.existsSync(SOURCE_FILE)) {
    console.error(` ERROR: Source file not found: ${SOURCE_FILE}`);
    process.exit(1);
  }
  const sourceContent = fs.readFileSync(SOURCE_FILE, "utf8");
  let enTranslation;
  try {
    enTranslation = JSON.parse(sourceContent);
  } catch (err) {
    console.error(`  ERROR: Failed to parse JSON: ${err.message}`);
    process.exit(1);
  }
  console.log(`  OK — ${Object.keys(enTranslation).length} top-level keys`);

  // 2. Flatten for translation
  const flat = flatten(enTranslation);
  console.log(`[2] Total strings to translate: ${flat.length}`);

  // 3. Translate all strings in a single API call
  console.log("[3] Translating…");
  let translatedRaw;
  try {
    translatedRaw = await translateWithMiniMax(JSON.stringify(enTranslation, null, 2));
  } catch (err) {
    console.error(`  ERROR: ${err.message}`);
    process.exit(1);
  }

  // 4. Parse the result
  let kaTranslation;
  const cleaned = stripMarkdown(translatedRaw);
  try {
    kaTranslation = JSON.parse(cleaned);
    console.log("  OK — parsed successfully");
  } catch (err) {
    console.error(`  ERROR: Failed to parse API response as JSON: ${err.message}`);
    console.error("  Raw response:");
    console.error(cleaned.slice(0, 1000));
    process.exit(1);
  }

  // 5. Validate — check that all keys are present
  const flatTranslated = flatten(kaTranslation);
  const missing = flat.filter(({ keyPath }) => !flatTranslated.find((f) => f.keyPath === keyPath));
  if (missing.length > 0) {
    console.warn(`  WARNING: ${missing.length} keys missing in translation:`);
    missing.forEach(({ keyPath }) => console.warn(`    - ${keyPath}`));
  } else {
    console.log("  OK — all keys present");
  }

  // 6. Save
  console.log(`[4] Writing: ${path.relative(ROOT, TARGET_FILE)}`);
  const output = JSON.stringify(kaTranslation, null, 2);
  fs.writeFileSync(TARGET_FILE, output, "utf8");
  console.log("  Done!\n");

  console.log("=== Translation complete ===\n");
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
