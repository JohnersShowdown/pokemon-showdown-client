Coolify deployment
==================

This repo ships a `Dockerfile` + `nginx/default.conf` that builds the client
and serves `play.pokemonshowdown.com/testclient.html` as the site root.

What it builds
--------------

A two-stage image:

1. **builder** — `node:20-bookworm-slim`. Installs npm deps, then runs
   `node build full`. That step:
   - clones `https://github.com/JohnersShowdown/johnpauls-showdown.git` into
     `caches/pokemon-showdown` and `npm run build`s it (needed to generate
     `play.pokemonshowdown.com/data/*.js` — pokedex, moves, items, abilities,
     search-index, teambuilder-tables);
   - compiles the TS/Babel sources under `play.pokemonshowdown.com/src/` into
     `play.pokemonshowdown.com/js/`;
   - rewrites cache-buster query strings on built HTML.
2. **runtime** — `nginx:1.27-alpine` serving `play.pokemonshowdown.com/` with
   `testclient.html` as the index. PHP shims (`crossdomain.php`, `ladder.php`,
   `customcss.php`, ...) return `404` since there is no PHP-FPM in the image.

Coolify setup
-------------

1. **New Resource → Application → Public/Private Repository**, point at this
   repo.
2. **Build Pack:** *Dockerfile*. Coolify will pick up `./Dockerfile` and
   `./.dockerignore` automatically.
3. **Port:** `80` (matches the `EXPOSE` in the Dockerfile).
4. **Domains:** add the public URL you want (e.g. `play.johnersshowdown.com`).
   Coolify provisions Let's Encrypt and proxies it via Traefik.
5. **Healthcheck:** the Dockerfile already declares `HEALTHCHECK` against
   `/testclient.html`. No extra config needed.
6. Click **Deploy**.

If `johnpauls-showdown` is private
----------------------------------

The build clones it over HTTPS unauthenticated. To use a token:

- In Coolify, set a **Build-time secret** named `GH_TOKEN`.
- Add to the `builder` stage of the Dockerfile, before `RUN node build full`:

  ```dockerfile
  RUN --mount=type=secret,id=GH_TOKEN \
      git config --global url."https://x-access-token:$(cat /run/secrets/GH_TOKEN)@github.com/".insteadOf "https://github.com/"
  ```

Pointing at your Showdown server
--------------------------------

`testclient.html` currently loads server defaults from
`https://play.pokemonshowdown.com/config/config.js` (hardcoded on line 15) and
accepts a `?~~host:port` query param to override at runtime.

For a permanent override, edit `play.pokemonshowdown.com/testclient.html` to
either:

- replace the external `config.js` `<script src=...>` with a local
  `config/config.js`, or
- hardcode `Config.server = { id, host, port }` after the existing IIFE that
  parses `location.search`.

Either edit lands in the build context and is baked into the image.

Things intentionally not included
---------------------------------

- **Sprites & audio** — large, not in the upstream repo (see README). If you
  have them, drop them under `play.pokemonshowdown.com/sprites/` and
  `play.pokemonshowdown.com/audio/` in the build context; they'll be copied
  into the image as-is. Otherwise, the client falls back to loading them from
  `play.pokemonshowdown.com` at runtime via the existing `onerror` handlers.
- **PHP backends** (replays, teams, login server, ladder). Hosting any of
  those requires a different image (PHP-FPM + MySQL) and is out of scope here.
- **`config/testclient-key.js`** — an *optional* file that pins a session
  cookie for the test client. Excluded by `.dockerignore` so it never ends up
  in a public image.

Local sanity check
------------------

```bash
docker build -t johners-client .
docker run --rm -p 8080:80 johners-client
# open http://localhost:8080/
```
