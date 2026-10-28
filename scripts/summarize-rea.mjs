#!/usr/bin/env node
// Inspect returned REA Evidence without inventing findings.
import { readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error("Usage: node scripts/summarize-rea.mjs <evidence.json> <report.md>");
  process.exit(2);
}

let evidence;
try { evidence = JSON.parse(readFileSync(input, "utf8")); }
catch (error) { console.error("REA Evidence is not valid JSON:", error.message); process.exit(1); }

const paths = new Set();
const moduleLike = new Set();
const stats = [];
const findings = [];
let seen = 0;
const visited = new WeakSet();
const stack = [{ value: evidence, depth: 0, key: "$" }];
const interesting = /(weapon|ammo|recoil|spread|shoot|fire|round|match|bot|ai|collis|map|network|snapshot|server|movement|score|damage|player|lag|input)/i;
const codePath = /(?:^|[/\\])(?:src|shared|server|client)[/\\].*\.(?:js|jsx|ts|tsx)$/i;

while (stack.length > 0 && seen < 300000) {
  const { value, depth, key } = stack.pop();
  seen++;
  if (value === null || typeof value !== "object") {
    if (typeof value === "string") {
      if (codePath.test(value) && value.length <= 400) paths.add(value);
      if (/(?:[\\/]|^)\S+\.(?:js|ts|jsx|tsx)$/.test(value) && value.length <= 400 && interesting.test(value)) moduleLike.add(value);
    }
    continue;
  }
  if (visited.has(value)) continue;
  visited.add(value);
  if (depth > 18) continue;
  if (Array.isArray(value)) {
    for (const item of value.slice(0, 10000)) stack.push({value:item, depth:depth+1, key});
    continue;
  }
  for (const [k, v] of Object.entries(value)) {
    if (/^(?:statistics|stats|coverage|limitations)$/i.test(k) && typeof v === "object") {
      stats.push({ key: k, value: JSON.stringify(v).slice(0, 1700) });
    }
    if (/(?:path|file|module|specifier)/i.test(k) && typeof v === "string" && v.length < 400) {
      if (codePath.test(v)) paths.add(v);
      else if (/\.(?:js|jsx|ts|tsx)$/.test(v) && interesting.test(v)) moduleLike.add(v);
    }
    if (/^(?:type|kind|status)$/i.test(k) && typeof v === "string") {
      if (interesting.test(v)) findings.push(`${key}.${k}: ${v}`);
    }
    if (typeof v === "object" && v !== null) stack.push({value:v, depth:depth+1, key:`${key}.${k}`});
  }
}
const discovered = [...new Set([...paths, ...moduleLike])].sort();
const relevant = discovered.filter(x=>interesting.test(x)).slice(0, 45);
const topKeys = Object.keys(evidence);
const raw = readFileSync(input);
const report = [
  "# REA FPS analysis — evidence projection",
  "",
  "Source: Hazzad123/fully-ai-arena-fps, MIT (Ben Darling), pinned commit `920b123d67015d5e8151a4ebd6742d8015d538be`.",
  "Analyzer: morluto/rea package `rea-agents@6.8.0` executed on the checked-out source, not on Roblox/RIVALS binaries.",
  `Evidence bytes: ${raw.byteLength}; JSON root keys: ${topKeys.map(k=>"`"+k+"`").join(", ") || "(none)"}.`,
  `Visited bounded JSON nodes: ${seen}; discovered JS/TS file-path candidates: ${discovered.length}.`,
  "",
  "## Paths observed in REA output",
  ...relevant.map(path=>`- \`${path.replaceAll("`","'")}\``),
  ...(relevant.length ? [] : ["No matching file paths surfaced in the projected schema; inspect the full Evidence artifact."]),
  "",
  "## Stats / coverage / limitations from REA",
  ...stats.slice(0, 10).flatMap(x=>[`- ${x.key}: \`${x.value.replaceAll("`","'")}\``]),
  ...(stats.length ? [] : ["No recognizable stats fields surfaced in this projection."]),
  "",
  "## Interpretation guardrails",
  "- This is a static dependency/module inventory. It does not prove the game runs or establishes match-balancing or weapon values.",
  "- Source-level gameplay interpretation must cite specific code in the pinned source or REA module evidence.",
  "- No proprietary RIVALS scripts, models or sounds were extracted.",
  ""
].join("\n");
writeFileSync(output,report);
console.log(report.slice(0,22000));
