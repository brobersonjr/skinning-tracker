#!/usr/bin/env node
// Runs the Lua test files under a real Lua VM (fengari, Lua 5.3 in JS).
//
// There is no system Lua interpreter on the maintainer's machine, but Node is
// present, so fengari is what makes these tests runnable at all. Usage:
//
//   npx --yes fengari && node tests/run.js
//   node tests/run.js            (fengari resolved via npx cache)
//
// Only pure-logic paths run here. Anything touching frames, timers or the
// client is stubbed to a no-op and still needs in-game verification.

const path = require('path');
const fs = require('fs');

let fengari;
try {
  fengari = require('fengari');
} catch (e) {
  console.error('fengari not found. Install it first:\n  npm install --no-save fengari');
  process.exit(2);
}

const { lua, lauxlib, lualib, to_luastring } = fengari;

const repoRoot = path.resolve(__dirname, '..');
const testDir = path.join(repoRoot, 'tests');

const testFiles = process.argv.slice(2).length
  ? process.argv.slice(2)
  : fs.readdirSync(testDir).filter((f) => f.endsWith('-tests.lua')).map((f) => path.join(testDir, f));

let failed = 0;

for (const file of testFiles) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  // Paths the test file uses to locate the stubs and the addon source
  lua.lua_pushstring(L, to_luastring(testDir.replace(/\\/g, '/')));
  lua.lua_setglobal(L, to_luastring('TEST_DIR'));
  lua.lua_pushstring(L, to_luastring(repoRoot.replace(/\\/g, '/')));
  lua.lua_setglobal(L, to_luastring('ADDON_DIR'));

  console.log(`\n=== ${path.basename(file)} ===`);
  const status = lauxlib.luaL_dofile(L, to_luastring(file.replace(/\\/g, '/')));
  if (status !== lua.LUA_OK) {
    const err = lua.lua_tojsstring(L, -1);
    console.error(`  ERROR  ${err}`);
    failed++;
  }
}

if (failed > 0) {
  console.error(`\n${failed} test file(s) failed.`);
  process.exit(1);
}
console.log('\nAll test files passed.');
