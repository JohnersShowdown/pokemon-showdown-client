/**
 * Generates a browser-compatible config/config.js (and the copy inside
 * play.pokemonshowdown.com/config/) with server values baked in at build time.
 *
 * Reads from environment variables (set via Docker ARGs / Coolify build args):
 *   SERVER_ID, SERVER_HOST, SERVER_PORT, SERVER_HTTPPORT,
 *   SERVER_ALTPORT, SERVER_REGISTERED
 */
'use strict';

const fs = require('fs');
const path = require('path');

const id = process.env.SERVER_ID || 'showdown';
const host = process.env.SERVER_HOST || 'sim3.psim.us';
const port = parseInt(process.env.SERVER_PORT || '443');
const httpport = parseInt(process.env.SERVER_HTTPPORT || '8000');
const altport = parseInt(process.env.SERVER_ALTPORT || '80');
const registered = process.env.SERVER_REGISTERED !== 'false';

const root = path.resolve(__dirname, '..');
const routesPath = path.join(root, 'config', 'routes.json');
const routes = JSON.parse(fs.readFileSync(routesPath, 'utf8'));

const js = `/** @type {import('../src/client-main').PSConfig} */
var Config = Config || {};

/* version */ Config.version = "0";

Config.bannedHosts = ['cool.jit.su', 'pokeball-nixonserver.rhcloud.com'];

Config.whitelist = [
	'wikipedia.org'
];

Config.defaultserver = {
	id: ${JSON.stringify(id)},
	host: ${JSON.stringify(host)},
	port: ${port},
	httpport: ${httpport},
	altport: ${altport},
	registered: ${registered}
};

Config.routes = {
	root: ${JSON.stringify(routes.root)},
	client: ${JSON.stringify(routes.client)},
	dex: ${JSON.stringify(routes.dex)},
	replays: ${JSON.stringify(routes.replays)},
	users: ${JSON.stringify(routes.users)},
	teams: ${JSON.stringify(routes.teams)},
};

Config.roomsFirstOpenScript = function () {
};

Config.customcolors = {};
`;

// Write the root config (used by build tools)
fs.writeFileSync(path.join(root, 'config', 'config.js'), js);

// Write a non-symlinked browser config directly into the served client tree.
const playConfigDir = path.join(root, 'play.pokemonshowdown.com', 'config');
fs.mkdirSync(playConfigDir, {recursive: true});
fs.writeFileSync(path.join(playConfigDir, 'config.generated.js'), js);

console.log(`[generate-config] Generated config.js → server: ${id}@${host}:${port}`);
