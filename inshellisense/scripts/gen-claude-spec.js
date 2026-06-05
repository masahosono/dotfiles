#!/usr/bin/env node
// inshellisense/scripts/gen-claude-spec.js
//
// Claude Code の CLI リファレンス（マークダウン）から
// inshellisense 用の Fig 互換スペック (specs/claude.js) を生成する。
//
// 使い方:
//   node inshellisense/scripts/gen-claude-spec.js
//   node inshellisense/scripts/gen-claude-spec.js --input /path/to/cli-reference.md
//   node inshellisense/scripts/gen-claude-spec.js --output /tmp/claude.js
//   node inshellisense/scripts/gen-claude-spec.js --url https://example.com/cli-reference.md
//
// `.js` だが ESM として動かすため scripts/package.json で type=module を宣言している。
// ドキュメント更新時に都度叩いて再生成する想定（自動化なし）。

import { writeFile, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const DOC_URL = "https://code.claude.com/docs/en/cli-reference.md";
const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_OUTPUT = resolve(__dirname, "..", "specs", "claude.js");

function parseArgs(argv) {
  const out = { input: null, output: DEFAULT_OUTPUT, url: DOC_URL };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--input") out.input = argv[++i];
    else if (a === "--output") out.output = argv[++i];
    else if (a === "--url") out.url = argv[++i];
    else if (a === "--help" || a === "-h") {
      console.log(
        "Usage: gen-claude-spec.mjs [--input <path>] [--output <path>] [--url <url>]",
      );
      process.exit(0);
    } else {
      console.error(`Unknown arg: ${a}`);
      process.exit(2);
    }
  }
  return out;
}

async function loadDoc({ input, url }) {
  if (input) return readFile(input, "utf8");
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`);
  return res.text();
}

// "| a | b | c |" → ["a", "b", "c"]. "\|" は中身としてアンエスケープする。
function parseTableRow(line) {
  const trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  const cells = [];
  let buf = "";
  for (let i = 0; i < trimmed.length; i++) {
    if (trimmed[i] === "\\" && trimmed[i + 1] === "|") {
      buf += "|";
      i++;
    } else if (trimmed[i] === "|") {
      cells.push(buf);
      buf = "";
    } else {
      buf += trimmed[i];
    }
  }
  cells.push(buf);
  return cells.map((c) => c.trim());
}

// 指定見出し直下にある最初のマークダウンテーブルを抽出する。
// header / separator 行は捨てて、データ行だけを返す。
function extractTable(md, headingRegex) {
  const lines = md.split("\n");
  let inSection = false;
  const blocks = [];
  let block = [];
  for (const line of lines) {
    if (/^#{1,6}\s/.test(line)) {
      if (block.length > 0) {
        blocks.push(block);
        block = [];
      }
      if (headingRegex.test(line)) {
        inSection = true;
      } else if (inSection) {
        break;
      }
      continue;
    }
    if (!inSection) continue;
    if (line.trimStart().startsWith("|")) {
      block.push(line);
    } else if (block.length > 0) {
      blocks.push(block);
      block = [];
    }
  }
  if (block.length > 0) blocks.push(block);
  if (blocks.length === 0) return [];
  // 1 行目 = ヘッダ、2 行目 = セパレータ、それ以降がデータ。
  return blocks[0].slice(2).map(parseTableRow);
}

// マークダウンの装飾を素朴に剥がす（リンクテキスト化、JSX コメント除去等）。
function cleanDescription(md) {
  let s = md;
  s = s.replace(/\{\/\*[\s\S]*?\*\/\}/g, "");
  s = s.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
  s = s.replace(/<br\s*\/?>/g, " ");
  s = s.replace(/`/g, "");
  s = s.replace(/\s+/g, " ").trim();
  return s;
}

function truncateDescription(s, limit = 240) {
  if (s.length <= limit) return s;
  const slice = s.slice(0, limit);
  const lastBreak = Math.max(slice.lastIndexOf(". "), slice.lastIndexOf("; "));
  if (lastBreak > limit / 2) return slice.slice(0, lastBreak + 1).trim();
  return slice.trimEnd() + "…";
}

function isRemovedFlag(desc) {
  return /\bRemoved in v?\d/i.test(desc);
}

// コマンド表の 1 行を {path, args} に分解する。
// `claude` 単体 / フラグだけ / パイプ例 はスキップ（null を返す）。
function parseCommandRow(snippet) {
  const inner = snippet.replace(/^`/, "").replace(/`$/, "");
  if (inner.includes("|")) return null;
  const tokens = inner.split(/\s+/);
  if (tokens[0] !== "claude") return null;
  const path = [];
  const args = [];
  for (let i = 1; i < tokens.length; i++) {
    const t = tokens[i];
    if (t.startsWith("--") || /^-[a-zA-Z]$/.test(t)) continue;
    if (t.startsWith('"')) continue;
    if (t.startsWith("<") && t.endsWith(">")) {
      args.push({ name: t.slice(1, -1) });
      continue;
    }
    if (t.startsWith("[") && t.endsWith("]")) {
      args.push({ name: t.slice(1, -1), isOptional: true });
      continue;
    }
    if (/^[a-zA-Z][\w-]*$/.test(t)) {
      path.push(t);
    }
  }
  if (path.length === 0) return null;
  return { path, args };
}

function buildSubcommandTree(rows) {
  const root = { children: new Map() };
  for (const cells of rows) {
    if (cells.length < 2) continue;
    const parsed = parseCommandRow(cells[0]);
    if (!parsed) continue;
    let node = root;
    for (const name of parsed.path) {
      if (!node.children.has(name)) {
        node.children.set(name, { children: new Map() });
      }
      node = node.children.get(name);
    }
    if (!node.description) {
      node.description = truncateDescription(cleanDescription(cells[1]));
    }
    if (parsed.args.length > 0 && !node.args) {
      node.args = parsed.args;
    }
  }
  return root;
}

function serializeSubcommand(node, name) {
  const out = { name };
  out.description = node.description || `${name} subcommand group`;
  if (node.args) {
    out.args = node.args.length === 1 ? node.args[0] : node.args;
  }
  if (node.children.size > 0) {
    out.subcommands = [];
    for (const [childName, childNode] of node.children) {
      out.subcommands.push(serializeSubcommand(childNode, childName));
    }
  }
  return out;
}

// フラグ表の 1 行を {names, args} に分解する。パースできなければ null。
function parseFlagRow(snippet) {
  const parts = snippet.split(",").map((p) => p.trim());
  const names = [];
  const args = [];
  for (const part of parts) {
    const inner = part.replace(/^`/, "").replace(/`$/, "");
    const m = inner.match(
      /^(-{1,2}[a-zA-Z][\w-]*)(?:\s+(<[^>]+>|\[[^\]]+\]))?$/,
    );
    if (!m) return null;
    names.push(m[1]);
    if (m[2]) {
      const argName = m[2].slice(1, -1);
      const isOptional = m[2].startsWith("[");
      const arg = { name: argName };
      if (isOptional) arg.isOptional = true;
      args.push(arg);
    }
  }
  if (names.length === 0) return null;
  return { names, args };
}

// Example 列を見て、フラグの直後に非フラグトークンが続くかを判定する。
// ドキュメントには `--flag <arg>` と明示されていないが値を取るフラグが多いので、
// Example での実用例からヒューリスティックに args の有無を補う。
function detectArgFromExample(exampleCell, flagNames) {
  const ex = exampleCell.replace(/`/g, "").trim();
  if (!ex) return null;
  const tokens = ex.match(/"[^"]*"|'[^']*'|\S+/g) || [];

  // 通常パス: Example 内のフラグ位置の直後トークンを見る。
  for (let i = 0; i < tokens.length; i++) {
    if (!flagNames.includes(tokens[i])) continue;
    const next = tokens[i + 1];
    if (!next) return null;
    if (next.startsWith("-")) return null;
    // ドキュメント全体で `"query"` は claude の prompt 用プレースホルダなので
    // フラグの値ではなく positional として扱う。
    const unquoted = next.replace(/^["']|["']$/g, "");
    if (unquoted === "query") return null;
    return { name: "value" };
  }

  // フォールバック: Example が `claude ...` 形式ではなく純粋な値リスト
  // (例: --allowedTools の `"Bash(git log *)" ...`) の場合は値を取るとみなす。
  if (!ex.startsWith("claude")) {
    return { name: "value" };
  }
  return null;
}

function buildOptions(rows) {
  const opts = [];
  for (const cells of rows) {
    if (cells.length < 2) continue;
    const parsed = parseFlagRow(cells[0]);
    if (!parsed) continue;
    const desc = truncateDescription(cleanDescription(cells[1]));
    if (isRemovedFlag(desc)) continue;
    const opt = {
      name: parsed.names.length === 1 ? parsed.names[0] : parsed.names,
      description: desc,
    };
    let args = parsed.args;
    if (args.length === 0 && cells.length >= 3) {
      const inferred = detectArgFromExample(cells[2], parsed.names);
      if (inferred) args = [inferred];
    }
    if (args.length > 0) {
      opt.args = args.length === 1 ? args[0] : args;
    }
    opts.push(opt);
  }
  return opts;
}

function emitSpec(spec, sourceUrl) {
  const json = JSON.stringify(spec, null, 2);
  return `// AUTO-GENERATED by inshellisense/scripts/gen-claude-spec.js
// Source: ${sourceUrl}
// 編集禁止 — 再生成は scripts/gen-claude-spec.js を実行する。

const spec = ${json};

export default spec;
`;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const md = await loadDoc(opts);

  const commandRows = extractTable(md, /^##\s+CLI commands\b/);
  const flagRows = extractTable(md, /^##\s+CLI flags\b/);
  if (commandRows.length === 0) {
    throw new Error("CLI commands テーブルが見つかりませんでした");
  }
  if (flagRows.length === 0) {
    throw new Error("CLI flags テーブルが見つかりませんでした");
  }

  const tree = buildSubcommandTree(commandRows);
  const subcommands = [];
  for (const [name, node] of tree.children) {
    subcommands.push(serializeSubcommand(node, name));
  }
  const options = buildOptions(flagRows);

  const spec = {
    name: "claude",
    description: "Claude Code CLI",
    subcommands,
    options,
  };

  const source = opts.input ? `(local) ${opts.input}` : opts.url;
  await writeFile(opts.output, emitSpec(spec, source));

  console.log(`Wrote ${opts.output}`);
  console.log(`  subcommands: ${subcommands.length} (top-level)`);
  console.log(`  options:     ${options.length}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
