#!/usr/bin/env bash
# Claude Code subagent status line (one row per task):
#   name ∙ description ∙ model effort ∙ tokens/context window
input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null)

# ---------- Colours / icons (same as statusline.sh) ----------
R=$'\033[0m'; M=$'\033[90m'; C_MUTED=$M
rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
C_HAIKU=$(rgb 134 207 134);
C_SONNET=$(rgb 122 162 247);
C_OPUS=$(rgb 255 150 50);
C_FABLE=$(rgb 187 154 247);
C_WHITE=$(rgb 255 255 255);
C_OFFWHITE=$(rgb 220 215 200);

SEP="${M} ∙ ${R}"
I_CONTEXT="⛁";

# Gradient blue (0%) -> red (100%)
grad() { local p=${1%.*}; [ -z "$p" ] && p=0; [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  rgb $((90 + 150 * p / 100)) $((140 - 60 * p / 100)) $((255 - 175 * p / 100)); }

fmt_tok() { awk -v n="$1" 'BEGIN{ if(n>=1000000) printf "%.1fM", n/1000000; else if(n>=1000) printf "%.1fk", n/1000; else printf "%d", n }'; }

# claude-opus-5-5[-20251001] -> Opus 5.5
fmt_model() { local m=${1#claude-}; m=${m%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]}
  local fam=${m%%-*} ver=${m#*-}; [ "$fam" = "$m" ] && ver=""
  printf '%s%s' "$(echo "${fam:0:1}" | tr '[:lower:]' '[:upper:]')${fam:1}" "${ver:+ ${ver//-/.}}"; }

while IFS= read -r row; do
  [ -z "$row" ] && continue
  id="" name="" desc="" model_id="" effort="" tokens="" size=""
  eval "$row"
  # Older Claude Code omits agentType; read it from the subagent's meta file
  meta="${transcript%.jsonl}/subagents/agent-${id}.meta.json"
  [ -z "$name" ] && [ -n "$transcript" ] && [ -f "$meta" ] && name=$(jq -r '.agentType // ""' "$meta" 2>/dev/null)

  line=""
  [ -n "$name" ] && line="${C_WHITE}${name}${R}"
  [ -n "$desc" ] && line+="${line:+$SEP}${C_OFFWHITE}${desc}${R}"

  m=""
  if [ -n "$model_id" ]; then
    case "$(echo "$model_id" | tr '[:upper:]' '[:lower:]')" in
      *fable*)  mcol=$C_FABLE;  micon="⛬" ;;
      *opus*)   mcol=$C_OPUS;   micon="λ" ;;
      *sonnet*) mcol=$C_SONNET; micon="⚼" ;;
      *haiku*)  mcol=$C_HAIKU;  micon="π" ;;
      *)        mcol="";        micon="" ;;
    esac
    m="${mcol}${micon:+$micon }$(fmt_model "$model_id")${R}"
  fi

  case "$effort" in
    low)    eicon="▶";   epos=0 ;;
    medium) eicon="▶▷";  epos=25 ;;
    high)   eicon="▶▶";  epos=50 ;;
    xhigh)  eicon="▶▶▷"; epos=75 ;;
    max)    eicon="▶▶▶"; epos=100 ;;
    *)      eicon="" ;;
  esac
  if [ -n "$eicon" ]; then m+="${m:+ }$(grad "$epos")${eicon} ${effort}${R}"
  elif [ -n "$effort" ]; then m+="${m:+ }${C_MUTED}$(fmt_tok "$effort")${R}"; fi
  [ -n "$m" ] && line+="${SEP}${m}"

  if [ -n "$tokens" ]; then
    if [ -n "$size" ] && [ "$size" -gt 0 ]; then
      used=$(( tokens * 100 / size ))
      line+="${SEP}$(grad "$used")${I_CONTEXT}${R} ${C_MUTED}$(fmt_tok "$tokens")/${C_OFFWHITE}$(fmt_tok "$size")${R}"
    else
      line+="${SEP}${C_MUTED}$(fmt_tok "$tokens")${R}"
    fi
  fi

  jq -nc --arg id "$id" --arg content "$line" '{id: $id, content: $content}'
done < <(echo "$input" | jq -r '
  .tasks[]? | [
    @sh "id=\(.id)",
    @sh "name=\(.name // .agentType // "" | gsub("[\r\n\t]+"; " "))",
    @sh "desc=\(.description // "" | gsub("[\r\n\t]+"; " "))",
    @sh "model_id=\(.model // "")",
    @sh "effort=\(.effort // "" | tostring)",
    @sh "tokens=\(.tokenCount // "" | tostring)",
    @sh "size=\(.contextWindowSize // "" | tostring)"
  ] | join(" ")' 2>/dev/null)

exit 0
