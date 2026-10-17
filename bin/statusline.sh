#!/usr/bin/env bash
# Claude Code status line (2 lines):
#   model/effort ∙ context ∙ cache ∙ cost/total tokens
#   folder ∙ git ∙ 5h gauge ∙ 7d gauge
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

SEP="${M} ∙ ${R}"
I_FOLDER="⊟";
I_GIT="⑂";
I_CACHE="⭍";
I_TOKENS="Σ";
I_CONTEXT="⛁";
I_ARROW="→";
G_FILLED="■";
G_HALF="◧";
G_EMPTY="□";
G_OPEN="[";
G_CLOSE="]";
G_CELLS=10;

# Gradient blue (0%) -> red (100%)
grad() { local p=${1%.*}; [ -z "$p" ] && p=0; [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  rgb $((90 + 150 * p / 100)) $((140 - 60 * p / 100)) $((255 - 175 * p / 100)); }

# Gauge with each cell coloured by its position on the gradient
gauge() { local p=${1%.*} units i out="${M}${G_OPEN}${R}" pos; [ -z "$p" ] && p=0
  units=$(( (p * G_CELLS * 2 + 50) / 100 ))
  for ((i = 0; i < G_CELLS; i++)); do
    pos=$(( (i * 100 + 50) / G_CELLS ))
    if [ $((units - i * 2)) -ge 2 ]; then out+="$(grad "$pos")${G_FILLED}"
    elif [ $((units - i * 2)) -eq 1 ]; then out+="$(grad "$pos")${G_HALF}"
    else out+="${M}${G_EMPTY}"; fi
  done
  printf '%s' "${out}${M}${G_CLOSE}${R}"; }

fmt_tok() { awk -v n="$1" 'BEGIN{ if(n>=1000000) printf "%.1fM", n/1000000; else if(n>=1000) printf "%.1fk", n/1000; else printf "%d", n }'; }
fmt_reset() { local diff=$(( ${1%.*} - $(date +%s) )); [ "$diff" -lt 0 ] && diff=0
  if [ "$diff" -ge 86400 ]; then printf '%dd%dh' $((diff/86400)) $((diff%86400/3600))
  elif [ "$diff" -ge 3600 ]; then printf '%dh%dm' $((diff/3600)) $((diff%3600/60))
  else printf '%dm' $((diff/60)); fi; }

# ---------- Line 1: model / effort / context ∙ cache / cost + tokens ----------
case "$(echo "$model_id $model" | tr '[:upper:]' '[:lower:]')" in
  *fable*)  mcol=$C_FABLE;  micon="⛬" ;;
  *opus*)   mcol=$C_OPUS;   micon="λ" ;;
  *sonnet*) mcol=$C_SONNET; micon="⚼" ;;
  *haiku*)  mcol=$C_HAIKU;  micon="π" ;;
  *)        mcol="";        micon="" ;;
esac
l1="${mcol}${micon:+$micon }${model:-?}${R}"

case "$effort" in
  low)    eicon="▶";   epos=0 ;;
  medium) eicon="▶▷";  epos=25 ;;
  high)   eicon="▶▶";  epos=50 ;;
  xhigh)  eicon="▶▶▷"; epos=75 ;;
  max)    eicon="▶▶▶"; epos=100 ;;
  *)      eicon="" ;;
esac
[ -n "$eicon" ] && l1+="${SEP}$(grad "$epos")${eicon} ${effort}${R}"

cache=""
if [ -n "$hit" ] || [ "$warm" = "true" ] || [ "$warm" = "false" ]; then
  ccol=$C_BLUE; [ "$warm" = "true" ] && ccol=$C_ORANGE
  cache="${ccol}${I_CACHE}${R}"
  [ -n "$hit" ] && cache+=" $(awk -v h="$hit" 'BEGIN{printf "%.0f", h*100}')%"
  [ "$warm" = "true" ] && cache+=" ${C_ORANGE}WARM${R}"
  [ "$warm" = "false" ] && cache+=" ${C_BLUE}COLD${R}"
fi

if [ -n "$used" ]; then
  [ -z "$cur" ] && [ -n "$size" ] && cur=$(awk -v u="$used" -v s="$size" 'BEGIN{printf "%d", u*s/100}')
  ctx="$(grad "$used")${I_CONTEXT}${R} ${C_OFFWHITE}$(printf '%.0f' "$used")%${R} ${C_OFFWHITE}${I_ARROW}${R}"
  [ -n "$cur" ] && [ -n "$size" ] && ctx+=" ${C_MUTED}$(fmt_tok "$cur")/${C_OFFWHITE}$(fmt_tok "$size")${R}"
  l1+="${SEP}${ctx}${cache:+$SEP$cache}"
elif [ -n "$cache" ]; then
  l1+="${SEP}${cache}"
fi

usage=""
[ -n "$cost" ] && usage+="${C_WHITE}\$${R}${C_OFFWHITE}$(printf '%.2f' "$cost")${R}"
# Every token of the session (input + output + cache write + cache read), main
# transcript plus subagents; streamed entries repeat a message id, so keep one per id
if [ -f "$transcript" ]; then
  stot=$(cat "$transcript" "${transcript%.jsonl}"/subagents/*.jsonl 2>/dev/null | jq -rn '
    reduce (inputs | select(.message.usage? and .message.id?) | .message) as $m ({}; .[$m.id] = $m.usage)
    | [.[] | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)]
    | add // 0' 2>/dev/null)
  [ -n "$stot" ] && usage+="${usage:+$SEP}${C_BLUE}${I_TOKENS}${R} $(fmt_tok "$stot")"
fi
[ -n "$usage" ] && l1+="${SEP}${usage}"

# ---------- Line 2: folder / git / rate limits ----------
l2="${C_WHITE}/${cwd##*/}${R}"

if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  read -r adds dels < <(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END{printf "%d %d\n", a, d}')
  l2+="${SEP}${C_BRANCH}${I_GIT} ${branch}${R} ${C_GREEN}+${adds:-0}${R} ${C_RED}-${dels:-0}${R}"
fi

for k in 5h:p5:r5 7d:p7:r7; do
  IFS=: read -r lab pv rv <<< "$k"
  p=${!pv}; r=${!rv}
  [ -z "$p" ] && continue
  seg="${C_OFFWHITE}${lab}${R} $(gauge "$p")"
  [ -n "$r" ] && seg+=" ${C_OFFWHITE}${I_ARROW}${R} ${M}$(fmt_reset "$r")${R}"
  l2+="${SEP}${seg}"
done

printf '%s\n' "$l1" "$l2"
exit 0
