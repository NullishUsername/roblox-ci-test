# roblox-ci-test

Rojo code + the builders' map → published to one Roblox game by GitHub Actions.

```
push to main (or "Run workflow")
  └─ Check dispatcher   (is this main? is the person allowed? which place?)
  └─ Build code         (rojo build → code.rbxl)
  └─ publish / Publish to <placeId>   "Deploying to test"
        download the game's latest saved version → swap in the code → publish it
```

**One game, one place.** Builders work in it in Studio like normal and **save**. CI is the only thing that **publishes**: every deploy takes the latest saved version (with the builders' newest map), replaces the code folders, and publishes that.

| Role | Does | How it reaches players |
|---|---|---|
| Builders | Edit the game in Studio, **File → Save to Roblox** | Next deploy |
| Scripters | Push to `main` | Deploys automatically |

Only these folders come from the repo; everything else (map, lighting, models) comes from the game itself:

| In the game | From |
|---|---|
| `ServerScriptService.Server` | `src/server` |
| `ReplicatedStorage.Shared` | `src/shared` |
| `StarterPlayer.StarterPlayerScripts.Client` | `src/client` |

---

## Setup, start to finish

Do these in order — the GitHub environment and secret must exist **before** the first push, because pushing to `main` deploys.

### 1. Install tools (once per machine)

Ubuntu:

```bash
sudo apt install git
# Rokit (toolchain manager) - see https://github.com/rojo-rbx/rokit if this URL changed
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
# restart your shell, then inside this repo:
rokit install        # installs the Rojo and Lune versions pinned in rokit.toml
```

Windows: install Rokit from its releases page and Git for Windows, and run the scripts from Git Bash.

### 2. Prepare the game

1. Open the game in Studio.
2. Delete any scripts that now live in this repo (they'd otherwise run twice), then **File → Save to Roblox**.
3. Tell everyone with edit access: **save, don't publish** (see *Day to day*).

### 3. Get the IDs

1. <https://create.roblox.com/dashboard/creations> → hover the experience → **⋯ → Copy Universe ID**.
2. Open the experience → **Places** → click the start place. The URL is
   `…/experiences/<universeId>/places/<placeId>/configure`.

Fill in `deploy-targets.json`:

```json
[
  { "environment": "test", "universe_id": "1234567890", "place_id": "9876543210" }
]
```

### 4. Create the Roblox API key

1. <https://create.roblox.com/dashboard/credentials> → **API Keys** → **Create API Key**.
   - Group-owned game? Switch the creator selector (top left) to the **group** first.
2. Name: `github-ci-test`.
3. **Access Permissions**, add two API systems:
   - **universe-places** → turn on **Restrict by Experience** → pick your game → tick **Write**. (Publishes.)
   - **legacy-asset** → tick **manage**. (Downloads the latest saved version.)
4. **Security**: leave IP addresses empty (GitHub runner IPs change constantly).
5. **Expiration**: pick a date (e.g. 90 days) and put a reminder in your calendar.
6. **Save & Generate Key** → **Copy Key to Clipboard**. It's only shown once.

Treat the key like a password — don't paste it into chats or issues, and never commit it.

### 5. Test everything locally first (recommended)

This runs exactly what CI runs, but uploads as **Saved** — it creates a new version without changing what players get.

```bash
export UNIVERSE_ID=1234567890 PLACE_ID=9876543210 BASE_PLACE_ID=9876543210   # same place
read -rsp "API key: " ROBLOX_API_KEY; export ROBLOX_API_KEY; echo

./scripts/download-place.sh base.rbxl            # 1. can we download the map?
rojo build default.project.json -o code.rbxl     # 2. build the code
lune run merge base.rbxl code.rbxl game.rbxl     # 3. merge
./scripts/publish.sh game.rbxl                   # 4. upload as Saved
```

Success: step 1 prints `Saved base.rbxl (… bytes)`, step 4 prints `HTTP 200` and `{"versionNumber": N}`. Check **Creator Dashboard → the place → Version History** for version N.

Also check the important part: move a part in Studio, **Save to Roblox** (don't publish), run step 1 again, and open `base.rbxl` in Studio. If the moved part is there, saved builder changes are picked up. If it isn't, the download only returns *published* versions — tell whoever set this up, because then builders would have to publish.

Fix any error here first (see Troubleshooting) — much faster than debugging in CI.

### 6. Create the GitHub repo and environment

1. Create a **new empty** repository on GitHub (no README/license).
2. **Settings → Environments → New environment** → `test`.
3. In `test`: **Environment secrets → Add environment secret** → `ROBLOX_API_KEY` = your key.
4. Optional: **Deployment branches and tags → Selected branches and tags → `main`**.
5. Leave **Required reviewers** off for test.

> Private repo on a free GitHub plan? Environment secrets for private repos need GitHub Pro (free for students via GitHub Education). Otherwise make the repo public, or add `ROBLOX_API_KEY` under **Settings → Secrets and variables → Actions** as a repository secret and delete the `environment:` block in `publish.yml`.

Only you (the repo owner) can trigger deploys by default. To allow others, add a repository variable `DEPLOYERS` (Settings → Secrets and variables → Actions → Variables), e.g. `yourname,friendname`.

### 7. First push

```bash
git init -b main          # skip if you cloned instead of unzipping
git add .
git commit -m "Set up Rojo + CI deploy"
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

Open the **Actions** tab: *Check dispatcher → Build code → publish / Publish to &lt;placeId&gt;* with **Deploying to test**.

### 8. Check it worked

- Join the test game in a **new** server (existing servers keep the old version until restarted). Bottom-right shows `build <commit>`, matching your latest commit.
- Dev console (F9) → Server log: `[CI test] Server running build <commit>`.
- The run's summary on GitHub shows the Roblox version number and which map it used.

Then have a builder move a part and **save**, click **Run workflow**, and check it shows up in a new server.

---

## Day to day

**Builders**
- Work in the game in Studio (Team Create) and use **File → Save to Roblox**. Team Create autosaves too.
- **Never File → Publish to Roblox.** That would make the version in your Studio session live — including whatever old scripts it has — until the next deploy fixes it.
- To get a map change live without a code change: **Actions → Deploy → Run workflow**. Or uncomment the `schedule:` block in `deploy.yml` to do that every few hours.
- Code deployed by CI doesn't appear in an already-open Studio session. Close and reopen the place to playtest with the latest code.

**Scripters**
- Push to `main` → deployed with the latest saved map.
- `rojo serve` into Studio is fine for testing. If you sync into the Team Create session, your in-progress code ends up in saved versions — harmless, because every deploy replaces the managed folders with what's in git.

**Rolling back the map:** set `BASE_VERSION=<n>` on the download step (version numbers are in the place's Version History). Prefer a committed map file instead? Set `"base_place_id": "committed"` in `deploy-targets.json` and commit `base.rbxl` (Git LFS; remove it from `.gitignore`).

---

## Troubleshooting

| Error | Fix |
|---|---|
| `ROBLOX_API_KEY secret is empty` | Secret not in the `test` environment, or name typo. |
| Download `HTTP 401` | Key invalid/expired, or missing **legacy-asset → manage**. |
| Download `HTTP 403` | Key owner can't access the place. Group game → key must belong to the group. |
| Download `HTTP 404` | Wrong place ID (or the `BASE_VERSION` doesn't exist). |
| `doesn't look like a place file` | The download returned something else — rerun; if it persists, the place may not be downloadable with this key. |
| Publish `HTTP 401` | Key missing **universe-places → Write** for this experience, or expired. |
| Publish `HTTP 403` | The key owner can't publish this place. |
| Publish `HTTP 404` / `409` | Wrong or swapped universe/place IDs. |
| Publish `HTTP 400` | Bad file — check the merge step's output. |
| `Missing container in base place` | The place lacks e.g. `StarterPlayerScripts` — re-add it in Studio and save. |
| Timeouts / huge file | Place over ~10 MiB. Remove unused assets from the map. |
| Builder's change missing | It wasn't saved to Roblox yet when the deploy ran. Save, then **Run workflow** again. |
| Old code live after a deploy | Someone published from Studio afterwards. **Run workflow** to fix, and remind them to save, not publish. |
| Scripts duplicated | Old scripts still in the game outside the managed folders. Delete them in Studio and save. |

## Adding a live environment later

1. Create a `live` environment with **Required reviewers** and **Prevent self-review**, and its own API key scoped to the live game.
2. Add a `live` entry to `deploy-targets.json` and `live` to the `target` options in `deploy.yml`.
3. Keep pushes going to `test`; promote to `live` with **Run workflow**.
