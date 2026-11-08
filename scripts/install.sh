# shellcheck shell=bash disable=SC2154
# Managed installation. Globals are initialized by scripts/yap.
no_symlink() {
  local path=$1 boundary=$2
  while :; do
    [[ ! -L $path ]] || return 1
    [[ $path != "$boundary" && $path != / && $path != . ]] || break
    path=$(dirname "$path")
  done
}
install_roots() {
  local h=$1 base=$2 prefix=''
  [[ $scope == project ]] || prefix=global_
  skills_root="$base/$(field "$h" "${prefix}skills_dir")"
  local prompt_dir
  prompt_dir=$(field "$h" "${prefix}prompts_dir")
  prompts_root=''
  [[ -z $prompt_dir ]] || prompts_root="$base/$prompt_dir"
}
load_lock() {
  local path=$1
  lock='{"files":{},"removals":[]}'
  if [[ -e $path || -L $path ]]; then
    [[ -f $path && ! -L $path ]] || die "invalid install lock: $path"
    lock=$(jq -sce 'select(length == 1) | .[0] | select(type == "object" and (.files | type == "object" and all(.[]; type == "string")) and ((.removals // []) | type == "array") and (.harness == null or (.harness | type == "string")) and (.scope == null or (.scope | type == "string"))) | .removals //= []' "$path") || die "invalid install lock: $path"
  fi
}
validate_destination() {
  local key=$1 dest=$2 base=$3 current recorded
  no_symlink "$dest" "$base" || die "refusing symlinked destination: $dest"
  if [[ -e $dest ]]; then
    [[ -f $dest ]] || die "not a regular file: $dest"
    if [[ $force == false ]]; then
      current=$(hash_file "$dest")
      recorded=$(jq -r --arg key "$key" '.files[$key] // empty' <<< "$lock")
      [[ $current == "$recorded" ]] || die "refusing to overwrite hand-edited or foreign file: $dest (pass --force to replace it)"
    fi
  fi
}
settings_plan() {
  local path=$1 ids=$2 existing='{}'
  if [[ -e $path ]]; then existing=$(jq -sce 'select(length == 1) | .[0] | select(type == "object")' "$path") || die "invalid settings: $path"; fi
  jq -ce --argjson ids "$ids" '
    if has("skills") and (.skills | type != "array" or any(.[]; type != "string")) then error("skills must be an array of strings") else . end |
    (.skills // []) as $existing |
    .skills = ($existing + [$ids[] | "!**/.agents/skills/" + . + "/SKILL.md" | select(. as $p | $existing | index($p) | not)])
  ' <<< "$existing" || die "invalid settings: $path"
}
voice_plan() {
  local h=$1 base=$2 output=$3 filename voice_base=$2
  voice_path=''
  [[ $voice == true && -f $root/skills/anon-writer/SKILL.md ]] || return 0
  filename=$(field "$h" instructions_file)
  case "$filename" in AGENTS.md|CLAUDE.md) ;; *) die "missing or invalid instructions_file for $h" ;; esac
  # Codex's global skills and global instructions have different native homes.
  if [[ $h == codex && $scope == global && -z $target ]]; then
    voice_base=${CODEX_HOME:-$HOME/.codex}
    [[ $voice_base == /* ]] || voice_base="$PWD/$voice_base"
  fi
  voice_path="${voice_base%/}/$filename"
  no_symlink "$voice_path" "$voice_base" || die "refusing symlinked instructions: $voice_path"
  [[ ! -e $voice_path || -f $voice_path ]] || die "not a regular instructions file: $voice_path"
  local input=/dev/null
  [[ ! -e $voice_path ]] || input=$voice_path
  # jq's raw strings preserve every byte outside our markers, including a
  # missing final newline. Fail closed on partial, duplicate or inline markers.
  frontmatter "$root/skills/anon-writer/SKILL.md" > "$work/voice-metadata.json"
  jq -j --rawfile original "$input" '
    (.body | sub("^\\s+"; "") | sub("\\s+$"; "")) as $guide |
    if ($guide | test("\\S") | not) then error("missing default voice guide") else . end |
    "<!-- bp3-yap:voice:begin -->" as $begin |
    "<!-- bp3-yap:voice:end -->" as $end |
    ($begin + "\n## Yap communication voice\n\nDefault communication voice: apply the full guide below to replies unless the user requests another tone.\n\n" + $guide +
      "\n\nThis block is managed by yap install.\n" + $end) as $block |
    ($original | split($begin)) as $parts |
    ($original | split($end)) as $ends |
    if $original == "" or (($parts | length) == 1 and ($ends | length) == 1) then
      $original + (if $original == "" or ($original | endswith("\n")) then "" else "\n" end) + $block + "\n"
    elif ($parts | length) == 2 and ($ends | length) == 2 then
      ($parts[1] | split($end)) as $tail |
      if ($tail | length) != 2 or
         ($parts[0] != "" and ($parts[0] | endswith("\n") | not)) or
         ($tail[0] | startswith("\n") | not) or
         ($tail[0] | endswith("\n") | not) or
         ($tail[1] != "" and ($tail[1] | startswith("\n") | not)) then
        error("malformed voice markers")
      else $parts[0] + $block + $tail[1] end
    else error("duplicate or incomplete voice markers") end
  ' "$work/voice-metadata.json" > "$output" || die "cannot update voice instructions: $voice_path"
}
retire_one() {
  local key=$1 dest=$2 base=$3 owned=$4 recorded
  recorded=$(jq -r --arg key "$key" '.files[$key] // empty' <<< "$lock")
  if [[ ! -e $dest && ! -L $dest ]]; then
    lock=$(jq --arg key "$key" 'del(.files[$key])' <<< "$lock")
  elif [[ $owned == true && -n $recorded && -f $dest ]] && no_symlink "$dest" "$base" && [[ $(hash_file "$dest") == "$recorded" ]]; then
    if [[ $dry_run == true ]]; then
      printf 'would remove retired file: %s\n' "$dest" >&2
    else
      printf 'removing retired file: %s\n' "$dest" >&2
      rm -- "$dest"
      if [[ $key != prompt:* ]]; then rmdir "$(dirname "$dest")" 2>/dev/null || true; fi
    fi
    lock=$(jq --arg key "$key" --arg path "$dest" --arg hash "$recorded" --arg version "$version" --argjson time "$(date +%s)" 'del(.files[$key]) | .removals += [{key:$key,path:$path,hash:$hash,version:$version,removed_at:$time}]' <<< "$lock")
  else
    printf 'preserved modified, foreign, or symlinked retired file: %s\n' "$dest" >&2
  fi
}
install_one() {
  local h=$1 base=$2 apply=$3 lock_path lock_h lock_scope owned=false source id key dest settings='' settings_path='' ids
  local voice_path='' voice_output="$work/voice-$1.md"
  install_roots "$h" "$base"
  lock_path="$skills_root/yap-skills.lock.json"
  no_symlink "$lock_path" "$base" || die "refusing symlinked lock path: $lock_path"
  load_lock "$lock_path"
  lock_h=$(jq -r '.harness // empty' <<< "$lock")
  lock_scope=$(jq -r '.scope // empty' <<< "$lock")
  if [[ $force == false ]]; then
    [[ -z $lock_h || $lock_h == "$h" ]] || die "skills root already managed for harness $lock_h: $skills_root"
    [[ -z $lock_scope || $lock_scope == "$scope" ]] || die "skills root already managed for scope $lock_scope: $skills_root"
  fi
  [[ $lock_h != "$h" || $lock_scope != "$scope" ]] || owned=true
  # Validate ALL writes, including settings, before any retirement deletion.
  while IFS= read -r source; do
    id=$(basename "$(dirname "$source")")
    validate_destination "$id" "$skills_root/$id/SKILL.md" "$base"
    [[ -z $prompts_root ]] || validate_destination "prompt:$id" "$prompts_root/$id.md" "$base"
  done < <(source_files)
  if [[ $h == pi ]]; then
    settings_path="$base/settings.json"
    [[ $scope != project ]] || settings_path="$base/.pi/settings.json"
    no_symlink "$settings_path" "$base" || die "refusing symlinked settings: $settings_path"
    ids=$(active_ids | jq -Rsc 'split("\n") | map(select(length > 0))')
    settings=$(settings_plan "$settings_path" "$ids")
  fi
  voice_plan "$h" "$base" "$voice_output"
  [[ $apply == true ]] || return 0
  if [[ -f $root/retired-skills.json ]]; then
    while IFS= read -r id; do
      retire_one "$id" "$skills_root/$id/SKILL.md" "$base" "$owned"
      [[ -z $prompts_root ]] || retire_one "prompt:$id" "$prompts_root/$id.md" "$base" "$owned"
    done < <(jq -r 'keys[]' "$root/retired-skills.json")
  fi
  while IFS= read -r source; do
    id=$(basename "$(dirname "$source")")
    for key in "$id" "prompt:$id"; do
      if [[ $key == prompt:* ]]; then
        [[ -n $prompts_root ]] || continue
        source="$work/prompts/$id.md"
        dest="$prompts_root/$id.md"
      else
        dest="$skills_root/$id/SKILL.md"
      fi
      if [[ $dry_run == false ]]; then
        mkdir -p "$(dirname "$dest")"
        cp "$source" "$dest"
      fi
      printf '%s\n' "$dest"
      lock=$(jq --arg key "$key" --arg hash "$(hash_file "$source")" '.files[$key] = $hash' <<< "$lock")
    done
  done < <(source_files)
  if [[ -n $settings_path ]]; then
    if [[ $dry_run == false ]]; then
      mkdir -p "$(dirname "$settings_path")"
      printf '%s\n' "$settings" > "$settings_path"
    fi
    printf '%s\n' "$settings_path"
  fi
  if [[ -n $voice_path ]]; then
    if [[ $dry_run == false ]]; then
      mkdir -p "$(dirname "$voice_path")"
      cp "$voice_output" "$voice_path"
    fi
    printf '%s\n' "$voice_path"
    if [[ -e $(dirname "$voice_path")/AGENTS.override.md && $h != claude ]]; then
      printf 'warning: AGENTS.override.md may shadow voice instructions: %s\n' "$voice_path" >&2
    fi
  fi
  if [[ $dry_run == false ]]; then
    mkdir -p "$skills_root"
    # Use a fresh temp path, never a predictable symlinkable lock.tmp.
    local lock_tmp
    lock_tmp=$(mktemp "$skills_root/.yap-lock.XXXXXX")
    jq --arg version "$version" --arg harness "$h" --arg scope "$scope" '.version=$version | .harness=$harness | .scope=$scope' <<< "$lock" > "$lock_tmp"
    mv -- "$lock_tmp" "$lock_path"
  fi
}
install_selected() {
  local h base other i j skills_root prompts_root lock version
  local bases=() roots=()
  [[ -n $scope ]] || die 'choose exactly one scope: -p/--project or -g/--global'
  [[ $scope != project || -n $target ]] || die 'install -p needs --target DIR'
  [[ $scope != global || -z $target || ${#selected[@]} == 1 ]] || die 'global --target requires exactly one harness'
  version=$(tr -d '\r\n' < "$root/VERSION")
  for h in "${selected[@]}"; do
    base=$target
    if [[ -z $base ]]; then
      [[ -n ${HOME:-} ]] || die 'HOME is not set'
      case "$h" in
        pi) base=${PI_CODING_AGENT_DIR:-$HOME/.pi/agent} ;;
        claude) base="$HOME/.claude" ;;
        codex) base="$HOME/.agents" ;;
        muse) base="${XDG_CONFIG_HOME:-$HOME/.config}/muse" ;;
      esac
    fi
    [[ $base == /* ]] || base="$PWD/$base"
    base=${base%/}
    [[ -n $base ]] || die 'refusing filesystem root as install target'
    install_roots "$h" "$base"
    for other in ${roots[@]+"${roots[@]}"}; do
      [[ $other != "$skills_root" ]] || die "selected harnesses share skills root: $skills_root"
    done
    bases+=("$base"); roots+=("$skills_root")
  done
  # Prepare prompt bodies before writes, and preflight every selected harness.
  copy_skills "$work/skills" "$work/prompts"
  for ((i=0; i<${#selected[@]}; i++)); do install_one "${selected[$i]}" "${bases[$i]}" false; done
  for ((j=0; j<${#selected[@]}; j++)); do install_one "${selected[$j]}" "${bases[$j]}" true; done
}
