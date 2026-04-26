/** @type {import('../play.pokemonshowdown.com/src/client-main').PSConfig} */
var Config = Config || {};

/* version */ Config.version = "0";

Config.bannedHosts = ['cool.jit.su', 'pokeball-nixonserver.rhcloud.com'];

Config.whitelist = [
	'wikipedia.org'

	// The full list is maintained outside of this repository so changes to it
	// don't clutter the commit log. Feel free to copy our list for your own
	// purposes; it's here: https://play.pokemonshowdown.com/config/config.js

	// If you would like to change our list, simply message Zarel on Smogon or
	// Discord.
];

// `defaultserver` specifies the server to use when the domain name in the
// address bar is `Config.routes.client`.
Config.defaultserver = {
	id: process.env.SERVER_ID || 'showdown',
	host: process.env.SERVER_HOST || 'kyqtcqmrxy8b18ddy1aweewz.15.204.211.28.sslip.io',
	port: parseInt(process.env.SERVER_PORT || '443'),
	httpport: parseInt(process.env.SERVER_HTTPPORT || '8000'),
	altport: parseInt(process.env.SERVER_ALTPORT || '80'),
	registered: process.env.SERVER_REGISTERED !== 'false'
};

Config.roomsFirstOpenScript = function () {
};

Config.customcolors = {
	'zarel': 'aeo'
};
