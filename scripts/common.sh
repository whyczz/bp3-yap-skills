# shellcheck shell=bash disable=SC2154
# Shared Bash helpers. Globals are initialized by scripts/yap.
die() { printf 'yap: %s\n' "$*" >&2; exit 2; }
need() { command -v "$1" >/dev/null || die "required command not found: $1"; }
valid_id() {
  [[ $1 =~ ^[a-z][a-z0-9_-]*$ ]] || return 1
  case "$1" in con|prn|aux|nul|com[1-9]|lpt[1-9]) return 1 ;; esac
}
hash_file() {
  # Keep the original OCaml lock's MD5 content fingerprints for upgrade compatibility.
  if command -v md5sum >/dev/null; then md5sum < "$1" | cut -d ' ' -f 1
  else md5 -q "$1"; fi
}
json_file() { jq -se 'length == 1 and (.[0] | type == "object")' "$1" >/dev/null || die "invalid JSON object: $1"; }
frontmatter() {
  local source=$1 scratch fields id
  scratch=$(mktemp -d "$work/frontmatter.XXXXXX")
  # Only split the document envelope here; yq parses the YAML itself.
  awk -v header="$scratch/header.yaml" -v body="$scratch/body.md" '
    NR == 1 { if ($0 != "---") exit 1; next }
    !closed && $0 == "---" { closed=1; next }
    { if (closed) print > body; else print > header }
    END { if (!closed) exit 1 }
  ' "$source" || { printf '%s: missing frontmatter delimiters\n' "$source" >&2; return 1; }
  touch "$scratch/header.yaml" "$scratch/body.md"
  # Check duplicate mapping keys before JSON conversion would discard them.
  yq -o=json '[.. | select(tag == "!!map") | keys]' "$scratch/header.yaml" |
    jq -e 'all(.[]; length == (unique | length))' >/dev/null || { printf '%s: invalid YAML or duplicate mapping keys\n' "$source" >&2; return 1; }
  fields=$(yq -o=json '.' "$scratch/header.yaml" | jq -sce '
    select(length == 1) | .[0] | select(type == "object") |
    select(.name | type == "string" and test("\\S")) |
    select(.description | type == "string" and test("\\S"))
  ') || { printf '%s: expected YAML mapping with nonempty name and description strings\n' "$source" >&2; return 1; }
  id=$(basename "$(dirname "$source")")
  jq -e --arg id "$id" '.name == $id' <<< "$fields" >/dev/null || { printf '%s: name must match directory\n' "$source" >&2; return 1; }
  jq -n --argjson fields "$fields" --rawfile body "$scratch/body.md" '{fields:$fields,body:$body}'
}
field() { jq -r --arg h "$1" --arg k "$2" '.[$h][$k] // empty' "$root/harnesses.json"; }
source_files() { find "$root/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | LC_ALL=C sort; }
active_ids() { source_files | while IFS= read -r source; do basename "$(dirname "$source")"; done; }
retirements_check() {
  local registry="$root/retired-skills.json" id replacement
  [[ -f $registry ]] || return 0
  json_file "$registry"
  while IFS= read -r id; do
    valid_id "$id" || die "invalid retired id: $id"
    [[ ! -e $root/skills/$id ]] || die "retired skill is still active: $id"
    jq -e --arg id "$id" '.[$id] | type == "object" and (.reason | type == "string" and test("\\S")) and (.replacement == null or (.replacement | type == "string"))' "$registry" >/dev/null || die "invalid retirement metadata: $id"
    replacement=$(jq -r --arg id "$id" '.[$id].replacement // empty' "$registry")
    if jq -e --arg id "$id" '.[$id].replacement != null' "$registry" >/dev/null; then
      valid_id "$replacement" && [[ -f $root/skills/$replacement/SKILL.md ]] || die "invalid retirement replacement: $id"
    fi
  done < <(jq -r 'keys[]' "$registry")
}
check_sources() {
  local source id count=0
  json_file "$root/harnesses.json"
  [[ -s $root/VERSION ]] || die 'missing VERSION'
  [[ -d $root/skills ]] || die 'missing skills directory'
  # Reject malformed directories and extra source files, not just valid discoveries.
  for source in "$root"/skills/*; do
    [[ -d $source && ! -L $source && -f $source/SKILL.md && ! -L $source/SKILL.md ]] || die "expected a skill directory with SKILL.md: $source"
    [[ $(find "$source" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') == 1 ]] || die "expected only SKILL.md: $source"
  done
  while IFS= read -r source; do
    id=$(basename "$(dirname "$source")")
    valid_id "$id" || die "invalid skill id: $id"
    frontmatter "$source" > /dev/null || die "invalid frontmatter: $id"
    [[ $(awk 'END {print NR}' "$source") -le 500 ]] || die "$id: over 500 lines"
    if grep -Eq 'TODO:|\{\{|\{%' "$source"; then die "$id: scaffold or template markers remain"; fi
    awk -F '`' -v id="$id" '/^\| `/ && $2 == id {found=1} END {exit !found}' "$root/README.md" || die "$id: missing from README roster"
    count=$((count + 1))
  done < <(source_files)
  [[ $count -gt 0 ]] || die 'no skills found'
  # Only table rows constitute the README roster.
  while IFS= read -r id; do
    [[ -f $root/skills/$id/SKILL.md ]] || die "README lists missing skill: $id"
  done < <(awk -F '`' '/^\| `/ {print $2}' "$root/README.md")
  retirements_check
  printf 'yap check: ok (%s skills)\n' "$count"
}
make_prompt() {
  local source=$1 dest=$2 metadata
  metadata=$(frontmatter "$source") || return 1
  mkdir -p "$(dirname "$dest")"
  jq -r '"---\ndescription: " + (.fields.description | tojson) + "\nargument-hint: \"[request]\"\n---\n" + (.body | sub("^\\s+"; "") | sub("\\s+$"; "")) + "\n\nUser request: ${ARGUMENTS:-}\n"' <<< "$metadata" > "$dest"
}
copy_skills() {
  local base=$1 prompts=$2 source id
  while IFS= read -r source; do
    id=$(basename "$(dirname "$source")")
    mkdir -p "$base/$id"
    cp "$source" "$base/$id/SKILL.md"
    if [[ -n $prompts ]]; then make_prompt "$source" "$prompts/$id.md"; fi
  done < <(source_files)
}
