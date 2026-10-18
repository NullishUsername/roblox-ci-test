# roblox-ci-test

Rojo code → merged into your map → published to a Roblox test place by GitHub Actions.

```
push to main
  └─ Check dispatcher   (is this main? is the pusher allowed? which place?)
  └─ Build place        (rojo build → merge into base.rbxl → game.rbxl)
  └─ publish / Publish to <placeId>   "Deploying to test"  (Open Cloud upload)
```

Only these folders come from this repo; everything else in the place (map, lighting, models) comes from `base.rbxl`:

| In the game | From |
|---|---|
| `ServerScriptService.Server` | `src/server` |
| `ReplicatedStorage.Shared` | `src/shared` |
| `StarterPlayer.StarterPlayerScripts.Client` | `src/client` |

---

## Setup, start to finish

Do the steps in order — the GitHub environment and secret must exist **before** the first push, because pushing to `main` deploys.

### 1. Install tools (once per machine)

Ubuntu:

```bash
sudo apt install git git-lfs
git lfs install

# Rokit (toolchain manager) - see https://github.com/rojo-rbx/rokit if this URL changed
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
# restart your shell, then inside this repo:
rokit install        # installs the Rojo and Lune versions pinned in rokit.toml
```

Windows: install Rokit from its releases page, Git for Windows (includes LFS), and run the scripts from Git Bash.

### 2. Get your test game's IDs

1. Go to <https://create.roblox.com/dashboard/creations>.
2. Hover your test experience → **⋯** → **Copy Universe ID**.
3. Open the experience → **Places** → click the start place. The URL is
   `…/experiences/<universeId>/places/<placeId>/configure`.

Put both into `deploy-targets.json`:

```json
[
  { "environment": "test", "universe_id": "1234567890", "place_id": "9876543210" }
]
```

`409 Place not part of the universe` later means these two are swapped or mismatched.

### 3. Export the map as `base.rbxl`

1. Open the test place in Studio.
2. **File → Save to File As…** → save as `base.rbxl` in the repo root.
3. If the place already has scripts you're moving into this repo, delete them from the place before exporting (or they'll run twice).

`base.rbxl` is stored with Git LFS (`.gitattributes` handles this). Whenever builders change the map, re-export and commit it again.

### 4. Create the Roblox API key

1. <https://create.roblox.com/dashboard/credentials> → **API Keys** → **Create API Key**.
   - Group-owned game? Switch the creator selector (top left) to the **group** first and create the key there.
2. Name: `github-ci-test`.
3. **Access Permissions** → **Select API System** → **universe-places** → **Add API System**.
4. Turn on **Restrict by Experience**, pick your test game, tick **Write**.
5. **Security**: leave IP addresses empty (GitHub runner IPs change constantly).
6. **Expiration**: pick a date (e.g. 90 days) and put a reminder in your calendar.
7. **Save & Generate Key** → **Copy Key to Clipboard**. It's only shown once.

Treat the key like a password - don't paste it into chats, issues, or commit it.

### 5. Test the key locally (recommended)

This builds exactly what CI builds and uploads it as **Saved** - it creates a new version but does **not** change what players get.

```bash
rojo build default.project.json -o code.rbxl
lune run merge base.rbxl code.rbxl game.rbxl
UNIVERSE_ID=1234567890 PLACE_ID=9876543210 ./scripts/publish.sh game.rbxl
# prompts for the key (hidden input)
```

Success looks like `HTTP 200` and `{"versionNumber": N}`. Check **Creator Dashboard → your place → Version History** — version N should be there.

If you get an error, fix it here first (see Troubleshooting) - it's much faster than debugging in CI.

### 6. Create the GitHub repo and environment

1. Create a **new empty** repository on GitHub (no README/license, so the first push is clean).
2. **Settings → Environments → New environment** → name it `test`.
3. In `test`: **Environment secrets → Add environment secret** → name `ROBLOX_API_KEY`, value = your key.
4. Optional: **Deployment branches and tags → Selected branches and tags → add `main`**.
5. Optional: leave **Required reviewers** off for test; turn it on for a future `live` environment.

> Private repo on a free GitHub plan? Environments/environment secrets for private repos need GitHub Pro or higher (free for students via GitHub Education). Otherwise make the repo public, or add `ROBLOX_API_KEY` under **Settings → Secrets and variables → Actions** as a repository secret and delete the `environment:` block in `publish.yml`.

Only you (the repo owner) can trigger deploys by default. To allow others, add a repository variable `DEPLOYERS` (Settings → Secrets and variables → Actions → Variables), e.g. `yourname,friendname`.

### 7. First push

```bash
git init -b main          # skip if you cloned instead of unzipping
git lfs track "*.rbxl"    # already in .gitattributes; harmless to repeat
git add .
git commit -m "Set up Rojo + CI deploy"
git lfs ls-files          # should list base.rbxl - if not, LFS isn't set up
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

Open the **Actions** tab. You should see the same graph as the original: *Check dispatcher → Build place → publish / Publish to &lt;placeId&gt;* with **Deploying to test**.

Pushes to `main` publish as **Published**. You can also run it manually: **Actions → Deploy → Run workflow**, and pick `Saved` to upload without going live.

### 8. Check it worked

- Join the game (a **new** server - existing servers keep the old version until restarted). Bottom-right shows `build <commit>` matching your latest commit.
- In-game dev console (F9) → Server log: `[CI test] Server running build <commit>`.
- The build's step summary on GitHub shows the Roblox version number.

Then change something in `src/`, push, and watch the label update.

---

## Troubleshooting

| Error | Fix |
|---|---|
| `ROBLOX_API_KEY secret is empty` | Secret not in the `test` environment, or name typo. |
| `HTTP 401` | Key missing **universe-places → Write** for this game, expired, or (group) revoked. Group game → key must be created under the group. |
| `HTTP 403` | The key's owner can't publish this place. |
| `HTTP 404` / `409` | Wrong or swapped universe/place IDs. |
| `HTTP 400` | Bad file. Check `game.rbxl` built and merged without errors. |
| `Base place 'base.rbxl' not found` | Step 3 not done, or LFS file not pushed (`git lfs ls-files` should list it). |
| `Missing container in base place` | Base place lacks e.g. `StarterPlayerScripts` - re-export from a normal Studio place. |
| Timeouts / huge file | Place over ~10 MiB. Remove unused assets from the map. |
| Map changes vanished | Someone published from Studio over the CI version, or `base.rbxl` is out of date. Re-export and commit. |
| Scripts vanished after a Studio publish | Publishing from Studio overwrites CI. After CI is set up, builders should only change the map and re-export `base.rbxl`; code changes go through git. |

## Adding a live environment later

1. Create a `live` environment with **Required reviewers** and **Prevent self-review**, and its own API key scoped to the live game.
2. Add a `live` entry to `deploy-targets.json` and `live` to the `target` options in `deploy.yml`.
3. Keep pushes going to `test`; promote to `live` with **Run workflow**.
