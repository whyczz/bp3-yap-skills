// Optional integration check against an installed Pi, without changing real settings.
// PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent node test/pi-discovery.mjs
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

assert.ok(process.env.PI_PACKAGE_ROOT, 'set PI_PACKAGE_ROOT to an installed Pi package');
const root = fileURLToPath(new URL('..', import.meta.url));
const home = fs.mkdtempSync(path.join(os.tmpdir(), 'yap-pi-discovery-'));
const previousHome = process.env.HOME;
process.env.HOME = home;
try {
  const agentDir = path.join(home, '.pi/agent');
  const cwd = path.join(home, 'project');
  fs.mkdirSync(cwd);
  const binary = path.join(root, 'scripts/yap');
  for (const [harness, target] of [['pi', agentDir], ['codex', path.join(home, '.agents')]]) {
    execFileSync(binary, ['install', '--root', root, '--harness', harness, '-g', '--target', target]);
  }
  // A project-level .agents variant should not shadow the Pi render either.
  const projectSkill = path.join(cwd, '.agents/skills/iiuc');
  fs.mkdirSync(projectSkill, {recursive: true});
  fs.copyFileSync(path.join(home, '.agents/skills/iiuc/SKILL.md'), path.join(projectSkill, 'SKILL.md'));
  // An unrelated .agents skill must remain discoverable.
  const foreign = path.join(home, '.agents/skills/unrelated');
  fs.mkdirSync(foreign);
  fs.writeFileSync(path.join(foreign, 'SKILL.md'), '---\nname: unrelated\ndescription: An unrelated skill.\n---\nKeep me.\n');
  const pkg = process.env.PI_PACKAGE_ROOT;
  const { DefaultPackageManager } = await import(pathToFileURL(path.join(pkg, 'dist/core/package-manager.js')));
  const { loadSkills } = await import(pathToFileURL(path.join(pkg, 'dist/core/skills.js')));
  const globalSettings = JSON.parse(fs.readFileSync(path.join(agentDir, 'settings.json'), 'utf8'));
  const manager = new DefaultPackageManager({cwd, agentDir, settingsManager: {
    getGlobalSettings: () => globalSettings,
    // Pi applies exclusions per scope: project copies need project settings.
    getProjectSettings: () => ({skills: ['!**/.agents/skills/iiuc/SKILL.md']}),
    isProjectTrusted: () => true,
  }});
  const resolved = await manager.resolve();
  const enabled = resolved.skills.filter(row => row.enabled).map(row => row.path);
  const result = loadSkills({cwd, agentDir, skillPaths: enabled, includeDefaults: false});
  assert.deepEqual(result.diagnostics, []);
  const ids = fs.readdirSync(path.join(root, 'skills'));
  assert.equal(result.skills.length, ids.length + 1);
  for (const id of ids) {
    const skill = result.skills.find(skill => skill.name === id);
    assert.ok(skill, `missing skill ${id}`);
    assert.equal(skill.filePath, path.join(agentDir, 'skills', id, 'SKILL.md'));
    assert.ok(fs.existsSync(path.join(home, '.agents/skills', id, 'SKILL.md')), 'Codex copy must survive');
  }
  assert.ok(result.skills.some(skill => skill.name === 'unrelated'));
  console.log(`pi-discovery: ok (${ids.length} Pi skills, unrelated skill retained, zero diagnostics)`);
} finally {
  process.env.HOME = previousHome;
  fs.rmSync(home, {recursive: true, force: true});
}
