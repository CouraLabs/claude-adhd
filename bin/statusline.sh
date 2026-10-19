#!/usr/bin/env bash
# Claude Code status line, one flowing line that wraps per block at $COLUMNS:
#   model/effort ❘ folder ❘ git ❘ context ❘ 5h ❘ 7d ❘ cost ❘ cache ❘ total tokens
input=$(cat)

eval "$(echo "$input" | jq -r '
  @sh "cwd=\(.workspace.project_dir // .cwd // "")",
  @sh "model=\(.model.display_name // "")",
  @sh "model_id=\(.model.id // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "used=\(.context_window.used_percentage // "")",
  @sh "size=\(.context_window.context_window_size // "")",
  @sh "cur=\(.context_window.current_usage | if . then ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)) else "" end)",
  @sh "cost=\(.cost.total_cost_usd // "")",
  @sh "transcript=\(.transcript_path // "")",
  @sh "hit=\(.prompt_cache.hit_ratio // "")",
  @sh "warm=\(.prompt_cache.warm | tostring)",
  @sh "p5=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "r5=\(.rate_limits.five_hour.resets_at // "")",
  @sh "p7=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "r7=\(.rate_limits.seven_day.resets_at // "")"
' 2>/dev/null)"

# Cache rate limits for /account-usage, which can't see the status line input
if [ -n "$p5$p7" ]; then
  rl_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/coura-labs"
  mkdir -p "$rl_dir" && echo "$input" | jq -c '{rate_limits, captured_at: now}' > "$rl_dir/rate-limits.json.$$" 2>/dev/null \
    && mv "$rl_dir/rate-limits.json.$$" "$rl_dir/rate-limits.json"
fi

# ---------- Colours / icons ----------
R=$'\033[0m'; M=$'\033[90m'; C_MUTED=$M
rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
C_HAIKU=$(rgb 134 207 134);
C_SONNET=$(rgb 122 162 247);
C_OPUS=$(rgb 255 150 50);
C_FABLE=$(rgb 187 154 247);
C_GREEN=$(rgb 120 200 120);
C_RED=$(rgb 235 90 90);
C_ORANGE=$(rgb 255 150 50);
C_BLUE=$(rgb 100 150 255);
C_BRANCH=$(rgb 240 175 120);
C_WHITE=$(rgb 255 255 255);
C_OFFWHITE=$(rgb 220 215 200);

SEP=$'\033[2;38;2;55;55;55m ❘ \033[0m'
I_FOLDER="⊟";
I_GIT="⑂";
I_CACHE="⭍";
I_TOKENS="Σ";
I_CONTEXT="⛁";
I_ARROW="→";
G_FILLED="█";
G_PARTIAL=("" "▒" "▓");
G_EMPTY="░";
G_CELLS=5;

# Gradient blue (0%) -> red (100%)
grad() { local p=${1%.*}; [ -z "$p" ] && p=0; [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  rgb $((90 + 150 * p / 100)) $((140 - 60 * p / 100)) $((255 - 175 * p / 100)); }

# Gauge bar with each cell coloured by its position on the gradient
gauge_bar() { local p=${1%.*} units i out="" pos rem; [ -z "$p" ] && p=0
  units=$(( (p * G_CELLS * 3 + 50) / 100 ))
  for ((i = 0; i < G_CELLS; i++)); do
    pos=$(( (i * 100 + 50) / G_CELLS )); rem=$((units - i * 3))
    if [ "$rem" -ge 3 ]; then out+="$(grad "$pos")${G_FILLED}"
    elif [ "$rem" -ge 1 ]; then out+="$(grad "$pos")${G_PARTIAL[rem]}"
    else out+="${M}${G_EMPTY}"; fi
  done
  printf '%s' "${out}${R}"; }
pct() { local p=${1%.*}; [ -z "$p" ] && p=0; printf '%s' "$(grad "$p")${p}%${R}"; }
gauge() { printf '%s' "$(gauge_bar "$1") $(pct "$1")"; }

fmt_tok() { awk -v n="$1" 'BEGIN{ if(n>=1000000) printf "%.1fM", n/1000000; else if(n>=1000) printf "%.1fk", n/1000; else printf "%d", n }'; }
fmt_reset() { local diff=$(( ${1%.*} - $(date +%s) )); [ "$diff" -lt 0 ] && diff=0
  if [ "$diff" -ge 86400 ]; then printf '%dd%dh' $((diff/86400)) $((diff%86400/3600))
  elif [ "$diff" -ge 3600 ]; then printf '%dh%dm' $((diff/3600)) $((diff%3600/60))
  else printf '%dm' $((diff/60)); fi; }

# ---------- Blocks (in display order) ----------
blocks=()
add() { [ -n "$1" ] && blocks+=("$1"); }

case "$(echo "$model_id $model" | tr '[:upper:]' '[:lower:]')" in
  *fable*)  mcol=$C_FABLE;  micon="⛬" ;;
  *opus*)   mcol=$C_OPUS;   micon="λ" ;;
  *sonnet*) mcol=$C_SONNET; micon="⚼" ;;
  *haiku*)  mcol=$C_HAIKU;  micon="π" ;;
  *)        mcol="";        micon="" ;;
esac
mblk="${mcol}${micon:+$micon }${model:-?}${R}"

case "$effort" in
  low)    elabel="low";   epos=0 ;;
  medium) elabel="med";   epos=25 ;;
  high)   elabel="high";  epos=50 ;;
  xhigh)  elabel="xhigh"; epos=75 ;;
  max)    elabel="max";   epos=100 ;;
  *)      elabel="" ;;
esac
[ -n "$elabel" ] && mblk+=" $(grad "$epos")${elabel}${R}"
add "$mblk"

# Where: folder + git
[ -n "$cwd" ] && add "${C_WHITE}${cwd##*/}${R}"
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  read -r adds dels < <(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END{printf "%d %d\n", a, d}')
  add "${C_BRANCH}${I_GIT} ${branch}${R} ${C_GREEN}+${adds:-0}${R} ${C_RED}-${dels:-0}${R}"
fi

# Budgets: context, 5h, 7d
if [ -n "$used" ]; then
  [ -z "$cur" ] && [ -n "$size" ] && cur=$(awk -v u="$used" -v s="$size" 'BEGIN{printf "%d", u*s/100}')
  ctx="$(grad "$used")${I_CONTEXT}${R} $(gauge "$used")"
  [ -n "$cur" ] && [ -n "$size" ] && ctx+=" ${C_OFFWHITE}${I_ARROW}${R} ${C_MUTED}$(fmt_tok "$cur")/${C_OFFWHITE}$(fmt_tok "$size")${R}"
  add "$ctx"
fi

for k in 5h:p5:r5 7d:p7:r7; do
  IFS=: read -r lab pv rv <<< "$k"
  p=${!pv}; r=${!rv}
  [ -z "$p" ] && continue
  seg="${C_OFFWHITE}${lab}${R} $(gauge "$p")"
  [ -n "$r" ] && seg+=" ${C_OFFWHITE}${I_ARROW}${R} ${M}$(fmt_reset "$r")${R}"
  add "$seg"
done

# Spend: cost, cache, total tokens
[ -n "$cost" ] && add "${C_WHITE}\$${R}${C_OFFWHITE}$(printf '%.2f' "$cost")${R}"

if [ -n "$hit" ] || [ "$warm" = "true" ] || [ "$warm" = "false" ]; then
  ccol=$C_BLUE; [ "$warm" = "true" ] && ccol=$C_ORANGE
  cache="${ccol}${I_CACHE}${R}"
  [ -n "$hit" ] && cache+=" $(awk -v h="$hit" 'BEGIN{printf "%.0f", h*100}')%"
  [ "$warm" = "true" ] && cache+=" ${C_ORANGE}♨${R}"
  [ "$warm" = "false" ] && cache+=" ${C_BLUE}❄${R}"
  add "$cache"
fi

# Every token of the session (input + output + cache write + cache read), main
# transcript plus subagents; streamed entries repeat a message id, so keep one per id
if [ -f "$transcript" ]; then
  stot=$(cat "$transcript" "${transcript%.jsonl}"/subagents/*.jsonl 2>/dev/null | jq -rn '
    reduce (inputs | select(.message.usage? and .message.id?) | .message) as $m ({}; .[$m.id] = $m.usage)
    | [.[] | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)]
    | add // 0' 2>/dev/null)
  [ -n "$stot" ] && add "${C_BLUE}${I_TOKENS}${R} $(fmt_tok "$stot")"
fi

# ---------- Flow layout: a block that doesn't fit moves whole to the next line ----------
export LC_ALL=en_US.UTF-8
ESC_RE=$'\033\\[[0-9;]*m'
vlen() { local s=$1; while [[ $s =~ $ESC_RE ]]; do s=${s/"${BASH_REMATCH[0]}"/}; done; printf '%d' "${#s}"; }

# Margin covers Claude Code's indent and glyphs some fonts draw double-width
width=$(( ${COLUMNS:-$(tput cols 2>/dev/null || echo 120)} - 4 ))
line=""; llen=0
for b in "${blocks[@]}"; do
  blen=$(vlen "$b")
  if [ -z "$line" ]; then line=$b; llen=$blen
  elif [ $((llen + 3 + blen)) -le "$width" ]; then line+="${SEP}${b}"; llen=$((llen + 3 + blen))
  else printf '%s\n' "$line"; line=$b; llen=$blen; fi
done
[ -n "$line" ] && printf '%s\n' "$line"
exit 0
