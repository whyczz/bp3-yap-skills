#!/bin/bash
# shellcheck disable=SC2016 # Fixtures deliberately contain literal Markdown/shell syntax.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
yap="$repo/scripts/yap"
work=$(mktemp -d "${TMPDIR:-/tmp}/yap-tests.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
checks=0
assert() { "$@" || { printf 'FAIL: %s\n' "$*" >&2; exit 1; }; checks=$((checks + 1)); }
rejects() {
  if "$@" > "$work/stdout" 2> "$work/stderr"; then printf 'FAIL: expected rejection: %s\n' "$*" >&2; exit 1; fi
  checks=$((checks + 1))
}
fixture() {
  fixture_count=$((fixture_count + 1))
  root="$work/fixture $fixture_count"
  mkdir -p "$root/skills/demo" "$root/templates"
  cp "$repo/harnesses.json" "$root/"
  cp "$repo/templates/skill.md" "$root/templates/"
  printf '0.1.0\n' > "$root/VERSION"
  printf '# Fixture\n\n| `demo` | Demo |\n' > "$root/README.md"
  printf -- '---\nname: demo\ndescription: "Does a thing: safely."\n---\n\n# Demo\n\nLiteral $HOME and `code` survive.\n' > "$root/skills/demo/SKILL.md"
}
fixture_count=0
"$yap" check --root "$repo"
"$yap" render --root "$repo" --all --out "$work/rendered" > /dev/null
"$yap" plugin --root "$repo" --harness pi,claude,codex,muse --out "$work/plugins" > /dev/null
for h in pi claude codex muse; do
  skills_dir=$(jq -r --arg h "$h" '.[$h].skills_dir' "$repo/harnesses.json")
  for source in "$repo"/skills/*/SKILL.md; do
    id=$(basename "$(dirname "$source")")
    assert cmp "$source" "$work/rendered/$h/$skills_dir/$id/SKILL.md"
    assert cmp "$source" "$work/plugins/$h/bp3/skills/$id/SKILL.md"
  done
done
assert jq -e '.pi.skills == ["./skills"] and .pi.prompts == ["./prompts/*.md"]' "$work/plugins/pi/bp3/package.json"
assert jq -e '.skills == "./skills/"' "$work/plugins/codex/bp3/.codex-plugin/plugin.json"
skill_count=$(find "$repo/skills" -name SKILL.md -type f | wc -l | tr -d ' ')
assert jq -e --argjson count "$skill_count" '.schemaVersion == 1 and (.capabilities.skills | length == $count)' "$work/plugins/muse/bp3/.muse-plugin/plugin.json"
assert jq -e '.name == "bp3"' "$work/plugins/claude/bp3/.claude-plugin/plugin.json"
assert grep -Fq '/bp3:{skill}' "$work/plugins/claude/bp3/README.md"
assert grep -Fq '${ARGUMENTS:-}' "$work/plugins/pi/bp3/prompts/iiuc.md"
assert test "$(yq --front-matter=extract '.description' "$work/plugins/pi/bp3/prompts/tldr.md")" = "$(yq --front-matter=extract '.description' "$repo/skills/tldr/SKILL.md")"
HARNESS=claude "$yap" render --root "$repo" --out "$work/default" > /dev/null
assert test -d "$work/default/pi"
assert test ! -d "$work/default/claude"
rejects "$yap" render --harness missing
rejects "$yap" install --root "$repo"
rejects "$yap" install --root "$repo" -p -g --target "$work/unused"
rejects "$yap" --unknown
rejects "$yap" render --root "$repo" --harness

# Actual YAML validation, not colon/quote heuristics.
fixture
"$yap" check --root "$root" --json | jq -e '. == []' > /dev/null
cp "$root/skills/demo/SKILL.md" "$work/good.md"
for header in \
  'name: demo\ndescription: Does a thing: badly' \
  'name: demo\ndescription: [unclosed' \
  'name: demo\ndescription: 123' \
  'name: demo\ndescription: ""' \
  'name: other\ndescription: Fine' \
  'name: demo\nname: demo\ndescription: Fine' \
  '- name: demo\n- description: Fine'; do
  printf -- '---\n%b\n---\nBody\n' "$header" > "$root/skills/demo/SKILL.md"
  rejects "$yap" check --root "$root"
done
printf -- '---\nname: demo\ndescription: |\n  Multiline: valid YAML.\n---\nBody\n' > "$root/skills/demo/SKILL.md"
"$yap" check --root "$root" > /dev/null
cp "$work/good.md" "$root/skills/demo/SKILL.md"
printf 'TODO: unfinished\n' >> "$root/skills/demo/SKILL.md"
rejects "$yap" check --root "$root"
cp "$work/good.md" "$root/skills/demo/SKILL.md"
printf '{{ invocation }}\n' >> "$root/skills/demo/SKILL.md"
rejects "$yap" check --root "$root"
cp "$work/good.md" "$root/skills/demo/SKILL.md"
awk 'BEGIN {for (i=0; i<501; i++) print "long"}' >> "$root/skills/demo/SKILL.md"
rejects "$yap" check --root "$root"
cp "$work/good.md" "$root/skills/demo/SKILL.md"
touch "$root/skills/demo/extra"
rejects "$yap" check --root "$root"
rm "$root/skills/demo/extra"
printf '| `missing` | Wrong |\n' >> "$root/README.md"
rejects "$yap" check --root "$root"
fixture
"$yap" new new-skill --root "$root" --description 'A thing: with "quotes".' > /dev/null
assert test "$(yq --front-matter=extract '.description' "$root/skills/new-skill/SKILL.md")" = 'A thing: with "quotes".'
rejects "$yap" check --root "$root"
rejects "$yap" new new-skill --root "$root"
rejects "$yap" new ../escape --root "$root"
rejects "$yap" new con --root "$root"

# Both install scopes, ownership, idempotence, settings merge, and JSON output.
fixture
base="$work/global base"
mkdir -p "$base"
printf '{"defaultModel":"keep","skills":["/extra","!**/ignored/**"]}\n' > "$base/settings.json"
"$yap" install --root "$root" -g --target "$base" --json > "$work/install.json"
assert jq -e 'length == 3' "$work/install.json"
assert cmp "$root/skills/demo/SKILL.md" "$base/skills/demo/SKILL.md"
assert jq -e '.scope == "global" and .harness == "pi" and (.files.demo | length == 32)' "$base/skills/yap-skills.lock.json"
assert jq -e '.defaultModel == "keep" and .skills == ["/extra","!**/ignored/**","!**/.agents/skills/demo/SKILL.md"]' "$base/settings.json"
cp "$base/settings.json" "$work/settings.before"
"$yap" install --root "$root" -g --target "$base" > /dev/null
assert cmp "$work/settings.before" "$base/settings.json"
printf 'my edit\n' >> "$base/skills/demo/SKILL.md"
rejects "$yap" install --root "$root" -g --target "$base"
"$yap" install --root "$root" -g --target "$base" --force > /dev/null
assert cmp "$root/skills/demo/SKILL.md" "$base/skills/demo/SKILL.md"
"$yap" install --root "$root" -p --target "$work/project" > /dev/null
assert test -f "$work/project/.pi/skills/demo/SKILL.md"
assert test -f "$work/project/.pi/prompts/demo.md"
assert test -f "$work/project/.pi/settings.json"
"$yap" install --root "$root" -p --target "$work/multi" --harness pi,claude > /dev/null
assert test -f "$work/multi/.claude/skills/demo/SKILL.md"
rejects "$yap" install --root "$root" -p --target "$work/clash" --harness codex,muse
assert test ! -e "$work/clash"
rejects "$yap" install --root "$root" -g --target "$base" --harness pi,claude
"$yap" install --root "$root" -g --target "$work/shared" --harness codex > /dev/null
rejects "$yap" install --root "$root" -g --target "$work/shared" --harness muse
mkdir -p "$work/foreign/skills/demo"
printf 'foreign\n' > "$work/foreign/skills/demo/SKILL.md"
rejects "$yap" install --root "$root" -g --target "$work/foreign"
"$yap" install --root "$root" -p --target "$work/fresh-dry" --dry-run > /dev/null
assert test ! -e "$work/fresh-dry"
PI_CODING_AGENT_DIR="$work/env-agent" "$yap" install --root "$root" -g > /dev/null
assert test -f "$work/env-agent/skills/demo/SKILL.md"
HOME="$work/home" XDG_CONFIG_HOME="$work/xdg" "$yap" install --root "$root" -g --harness muse > /dev/null
assert test -f "$work/xdg/muse/skills/demo/SKILL.md"

# Legacy OCaml MD5 locks remain usable even when source content has changed.
legacy="$work/legacy"
mkdir -p "$legacy/skills/demo" "$legacy/prompts"
printf 'old installed body\n' > "$legacy/skills/demo/SKILL.md"
printf 'old installed prompt\n' > "$legacy/prompts/demo.md"
if command -v md5sum >/dev/null; then
  hash=$(md5sum < "$legacy/skills/demo/SKILL.md" | cut -d ' ' -f 1)
  prompt_hash=$(md5sum < "$legacy/prompts/demo.md" | cut -d ' ' -f 1)
else
  hash=$(md5 -q "$legacy/skills/demo/SKILL.md")
  prompt_hash=$(md5 -q "$legacy/prompts/demo.md")
fi
jq -n --arg hash "$hash" --arg prompt_hash "$prompt_hash" '{version:"0.1.0",harness:"pi",scope:"global",files:{demo:$hash,"prompt:demo":$prompt_hash}}' > "$legacy/skills/yap-skills.lock.json"
"$yap" install --root "$root" -g --target "$legacy" > /dev/null
assert cmp "$root/skills/demo/SKILL.md" "$legacy/skills/demo/SKILL.md"

# Explicit retirement only; test every harness and both scope path shapes.
for pair in pi:global pi:project claude:project codex:global muse:global; do
  fixture
  h=${pair%:*}; scope=${pair#*:}; flag=-g
  [[ $scope != project ]] || flag=-p
  mkdir -p "$root/skills/old"
  printf -- '---\nname: old\ndescription: Old skill.\n---\nOld\n' > "$root/skills/old/SKILL.md"
  printf '| `old` | Old |\n' >> "$root/README.md"
  target="$work/retire-$h-$scope"
  "$yap" install --root "$root" "$flag" --target "$target" --harness "$h" > /dev/null
  prefix=global_
  [[ $scope != project ]] || prefix=''
  dir=$(jq -r --arg h "$h" --arg key "${prefix}skills_dir" '.[$h][$key]' "$root/harnesses.json")
  lock="$target/$dir/yap-skills.lock.json"
  old="$target/$dir/old/SKILL.md"
  rm -r "$root/skills/old"
  printf '# Fixture\n\n| `demo` | Demo |\n' > "$root/README.md"
  printf '{"old":{"replacement":"demo","reason":"Renamed."}}\n' > "$root/retired-skills.json"
  cp "$lock" "$work/lock.before"
  "$yap" install --root "$root" "$flag" --target "$target" --harness "$h" --dry-run > /dev/null
  assert test -f "$old"
  assert cmp "$work/lock.before" "$lock"
  printf 'keep\n' > "$(dirname "$old")/notes.txt"
  "$yap" install --root "$root" "$flag" --target "$target" --harness "$h" > /dev/null
  assert test ! -e "$old"
  assert test -f "$(dirname "$old")/notes.txt"
  expected=1; [[ $h != pi ]] || expected=2
  assert jq -e --argjson count "$expected" '.files.old == null and (.removals | length == $count)' "$lock"
  cp "$lock" "$work/retired.before"
  "$yap" install --root "$root" "$flag" --target "$target" --harness "$h" > /dev/null
  assert cmp "$work/retired.before" "$lock"
done

# Modified, foreign, and symlinked retirements survive even --force.
for kind in modified foreign symlink parent-symlink; do
  fixture
  mkdir -p "$root/skills/old"
  printf -- '---\nname: old\ndescription: Old.\n---\nOld\n' > "$root/skills/old/SKILL.md"
  printf '| `old` | Old |\n' >> "$root/README.md"
  target="$work/preserve-$kind"
  "$yap" install --root "$root" -g --target "$target" > /dev/null
  old="$target/skills/old/SKILL.md"
  lock="$target/skills/yap-skills.lock.json"
  rm -r "$root/skills/old"
  printf '# Fixture\n\n| `demo` | Demo |\n' > "$root/README.md"
  printf '{"old":{"replacement":null,"reason":"Removed."}}\n' > "$root/retired-skills.json"
  case "$kind" in
    modified) printf 'edit\n' >> "$old" ;;
    foreign) jq 'del(.files.old)' "$lock" > "$work/changed-lock"; cp "$work/changed-lock" "$lock" ;;
    symlink) cp "$old" "$work/outside-$kind"; rm "$old"; ln -s "$work/outside-$kind" "$old" ;;
    parent-symlink) mkdir "$work/outside-$kind"; mv "$old" "$work/outside-$kind/"; rmdir "$(dirname "$old")"; ln -s "$work/outside-$kind" "$(dirname "$old")" ;;
  esac
  "$yap" install --root "$root" -g --target "$target" --force > /dev/null
  assert test -f "$old"
done

# Invalid metadata fails closed; settings/conflicts abort before cleanup/writes.
fixture
for registry in \
  '{"../escape":{"reason":"unsafe"}}' \
  '{"demo":{"reason":"still active"}}' \
  '{"old":{"replacement":"missing","reason":"bad"}}' \
  '{"old":{"replacement":"","reason":"bad"}}' \
  '{"old":{"replacement":null,"reason":""}}'; do
  printf '%s\n' "$registry" > "$root/retired-skills.json"
  rejects "$yap" check --root "$root"
done
rm "$root/retired-skills.json"
base="$work/invalid"
"$yap" install --root "$root" -g --target "$base" > /dev/null
cp "$base/skills/demo/SKILL.md" "$work/before.md"
printf '{broken' > "$base/skills/yap-skills.lock.json"
rejects "$yap" install --root "$root" -g --target "$base" --force
assert cmp "$work/before.md" "$base/skills/demo/SKILL.md"
rm "$base/skills/yap-skills.lock.json"
printf '{broken' > "$base/settings.json"
rejects "$yap" install --root "$root" -g --target "$base" --force
assert cmp "$work/before.md" "$base/skills/demo/SKILL.md"
printf '{"skills":null}' > "$base/settings.json"
rejects "$yap" install --root "$root" -g --target "$base" --force

# Source absence alone is not permission to prune; conflicts/settings failures
# must precede every retirement deletion and active write.
fixture
mkdir -p "$root/skills/old"
printf -- '---\nname: old\ndescription: Old.\n---\nOld\n' > "$root/skills/old/SKILL.md"
printf '| `old` | Old |\n' >> "$root/README.md"
base="$work/preflight"
"$yap" install --root "$root" -g --target "$base" > /dev/null
old="$base/skills/old/SKILL.md"
lock="$base/skills/yap-skills.lock.json"
rm -r "$root/skills/old"
printf '# Fixture\n\n| `demo` | Demo |\n' > "$root/README.md"
"$yap" install --root "$root" -g --target "$base" > /dev/null
assert test -f "$old"
printf '{"old":{"replacement":"demo","reason":"Renamed."}}\n' > "$root/retired-skills.json"
printf 'hand edit\n' >> "$base/skills/demo/SKILL.md"
cp "$lock" "$work/preflight-lock"
rejects "$yap" install --root "$root" -g --target "$base"
assert test -f "$old"
assert cmp "$work/preflight-lock" "$lock"
cp "$root/skills/demo/SKILL.md" "$base/skills/demo/SKILL.md"
printf '{broken' > "$base/settings.json"
rejects "$yap" install --root "$root" -g --target "$base"
assert test -f "$old"
assert cmp "$work/preflight-lock" "$lock"
rm "$base/settings.json"
# Broken/foreign lock shape is rejected even with force.
printf '{}\n' > "$lock"
rejects "$yap" install --root "$root" -g --target "$base" --force
assert test -f "$old"
cp "$work/preflight-lock" "$lock"
printf '{}\n' >> "$lock"
rejects "$yap" install --root "$root" -g --target "$base" --force
assert test -f "$old"
cp "$work/preflight-lock" "$lock"
# Force must not follow an active destination symlink.
cp "$base/skills/demo/SKILL.md" "$work/active-outside"
rm "$base/skills/demo/SKILL.md"
ln -s "$work/active-outside" "$base/skills/demo/SKILL.md"
rejects "$yap" install --root "$root" -g --target "$base" --force
assert cmp "$root/skills/demo/SKILL.md" "$work/active-outside"
assert test -f "$old"
# Multi-harness preflight prevents the first harness writing before a later
# harness conflict is detected.
mkdir -p "$work/multi-conflict/.claude/skills/demo"
printf 'foreign\n' > "$work/multi-conflict/.claude/skills/demo/SKILL.md"
rejects "$yap" install --root "$root" -p --target "$work/multi-conflict" --harness pi,claude
assert test ! -e "$work/multi-conflict/.pi"

printf 'test_yap: ok (%s assertions)\n' "$checks"
