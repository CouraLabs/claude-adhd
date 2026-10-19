#!/usr/bin/env bash
# Account usage report in markdown:
#   rate limits (5h / 7d) from the status line's cache, and token usage from every
#   local transcript (main + subagents), bucketed by 24h / 7d / 30d / 60d / 90d / all time.
# Colors are emoji, since the output is rendered as markdown rather than ANSI.
# Streamed entries repeat a message id (and resumed sessions copy them), so keep one per id.
base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
root="$base/projects"
rl="$base/coura-labs/rate-limits.json"

# ---------- Rate limits ----------
echo "### ⏱️ Rate limits"
echo
if [ -f "$rl" ]; then
  jq -r '
    def gauge: (. / 10 | round) as $n
      | (if . >= 90 then "🟥" elif . >= 75 then "🟧" elif . >= 50 then "🟨" else "🟩" end) as $c
      | ([range(0; $n)] | map($c) | join("")) + ([range($n; 10)] | map("⬛") | join(""));
    def dur: if . >= 86400 then "\(. / 86400 | floor)d \(. % 86400 / 3600 | floor)h"
      elif . >= 3600 then "\(. / 3600 | floor)h \(. % 3600 / 60 | floor)m"
      else "\(. / 60 | floor)m" end;
    (now) as $now
    | "| Window | Usage | | Resets in |",
      "|---|---|--:|--:|",
      ([["5h", .rate_limits.five_hour], ["7d", .rate_limits.seven_day]][]
        | select(.[1].used_percentage != null)
        | .[0] as $lab | .[1] as $w
        | if ($w.resets_at // 0) > 0 and $w.resets_at <= $now
          then "| \($lab) | \(0 | gauge) | 0% | ✅ reset |"
          else "| \($lab) | \($w.used_percentage | gauge) | **\($w.used_percentage | round)%** | \(if $w.resets_at then ($w.resets_at - $now | dur) else "?" end) |"
          end),
      "",
      "As of \(($now - .captured_at) | if . < 60 then "just now" else "\(dur) ago" end)."
  ' "$rl"
else
  echo "No rate-limit data yet — it's captured by the coura-labs status line."
fi
echo

# ---------- Token usage ----------
echo "### 📊 Token usage"
echo
[ -d "$root" ] || { echo "No transcripts found in $root"; exit 0; }

find "$root" -name '*.jsonl' -type f -print0 2>/dev/null | xargs -0 cat 2>/dev/null | jq -rn '
  def fmt: if . >= 1e9 then "\(. / 1e9 * 100 | round / 100)B"
    elif . >= 1e6 then "\(. / 1e6 * 10 | round / 10)M"
    elif . >= 1e3 then "\(. / 1e3 * 10 | round / 10)k"
    else tostring end;
  def bar($max): (if $max > 0 then . / $max * 8 | round else 0 end) as $n
    | ([range(0; $n)] | map("🟦") | join("")) + ([range($n; 8)] | map("⬛") | join(""));

  reduce (inputs | select(.message.usage? and .message.id? and .timestamp?)) as $e ({};
    .[$e.message.id] = {
      t: ($e.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601),
      i: ($e.message.usage.input_tokens // 0),
      o: ($e.message.usage.output_tokens // 0),
      w: ($e.message.usage.cache_creation_input_tokens // 0),
      r: ($e.message.usage.cache_read_input_tokens // 0)
    })
  | [.[]] as $all
  | (now) as $now
  | ($all | map(.t) | min) as $oldest
  | [["24h", 86400], ["7d", 604800], ["30d", 2592000], ["60d", 5184000], ["90d", 7776000], ["All time", null]]
  | map(. as [$label, $secs]
      | [$all[] | select($secs == null or .t >= $now - $secs)]
      | { label: $label, n: length,
          i: (map(.i) | add // 0), o: (map(.o) | add // 0),
          w: (map(.w) | add // 0), r: (map(.r) | add // 0) }
      | .total = .i + .o + .w + .r)
  | (last.total) as $max
  | "| Period | Share of all time | **Total** | Input | Output | Cache write | Cache read | Msgs |",
    "|---|---|--:|--:|--:|--:|--:|--:|",
    (.[] | "| \(.label) | \(.total | bar($max)) | **\(.total | fmt)** | \(.i | fmt) | \(.o | fmt) | \(.w | fmt) | \(.r | fmt) | \(.n) |"),
    "",
    (if $oldest then "Data since \($oldest | strftime("%Y-%m-%d")) (local transcripts on this machine)."
     else "No usage recorded yet." end)
'
