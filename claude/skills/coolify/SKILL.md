---
name: coolify
description: Manage and troubleshoot Coolify-hosted applications via the Coolify REST API — list servers/apps, read deploy logs and container logs, inspect and edit env vars, trigger deploy/restart/stop, check deployment history, and diagnose crash loops or data-loss incidents. Use whenever a Coolify app is broken, needs a deploy/restart, or its env/volumes need inspection.
---

# Coolify management

Operate Coolify over its REST API v1. Every call is `curl` + a Bearer token.

## 1. Credentials

Two env vars: `COOLIFY_URL` (e.g. `https://coolify.example.com`) and `COOLIFY_TOKEN`.

Check first — they are usually already loaded:

```bash
[ -n "$COOLIFY_TOKEN" ] && echo "token present (${#COOLIFY_TOKEN} chars)" || echo "MISSING"
echo "$COOLIFY_URL"
```

### If missing — set up persistently

Never paste the token into chat, a commit, or a script body. It lives in one 0600 file.

Get the token: Coolify UI → **Keyboard/profile menu → Security → API tokens → Create New Token**.
Scope: `root` for full management (deploy/env/logs); `read-only` if only inspecting.

Ask the operator to run these (the `!` prefix runs it in their own shell, so the token
never enters the transcript):

```bash
! mkdir -p ~/.config/coolify && touch ~/.config/coolify/env && chmod 600 ~/.config/coolify/env
! ${EDITOR:-nano} ~/.config/coolify/env
```

File content (two lines):

```bash
export COOLIFY_URL=https://coolify.example.com
export COOLIFY_TOKEN=paste-token-here
```

Load it on every shell — append to `~/.zshrc`:

```bash
! grep -q 'config/coolify/env' ~/.zshrc || echo '[ -f ~/.config/coolify/env ] && source ~/.config/coolify/env' >> ~/.zshrc
! source ~/.config/coolify/env && echo "loaded: ${#COOLIFY_TOKEN} chars"
```

Rules:
- Reference only `$COOLIFY_TOKEN`. Never echo its value, never inline it in a command.
- If it ever reaches the transcript, a log, or a repo: **rotate it in the UI immediately**.
- No token in `.env` of a project, in CI config, or in a compose file.

## 2. Call pattern

```bash
cf() { curl -s -H "Authorization: Bearer $COOLIFY_TOKEN" -H "Content-Type: application/json" "$COOLIFY_URL/api/v1$1" "${@:2}"; }
```

Use `curl`, not Python `urllib` — some Coolify deployments return HTTP 403 to non-curl
user agents.

Add `| python3 -m json.tool` or `| jq` to read output. Responses can be large; filter
with `jq` rather than dumping everything.

## 3. Recipes

Discovery:

```bash
cf /servers        | jq '.[] | {name, ip, uuid}'
cf /applications   | jq '.[] | {name, uuid, status, fqdn, git_branch, build_pack}'
cf /projects       | jq '.[] | {name, uuid}'
```

One app (`U` = app uuid):

```bash
cf "/applications/$U" | jq '{name,status,fqdn,git_repository,git_branch,build_pack,docker_compose_location,destination:.destination.name}'
```

Logs — container stdout, the fastest signal for a crash loop:

```bash
cf "/applications/$U/logs?lines=400" | jq -r '.logs'
```

Deployment history and one deployment's build log:

```bash
cf "/deployments/applications/$U?take=10" | jq '.deployments[] | {id,status,commit,created_at,finished_at}'
cf "/deployments/$DEPLOYMENT_UUID"        | jq -r '.logs'
```

Env vars (**keys and metadata only — never print values**):

```bash
cf "/applications/$U/envs" | jq -r '.[] | "\(.key) len=\(.value|length) updated=\(.updated_at)"'
```

Watch for **duplicate keys** — Coolify allows two entries with the same key and which one
wins is not obvious. Deduplicate.

Update / create one env var:

```bash
cf "/applications/$U/envs" -X PATCH -d '{"key":"FOO","value":"bar","is_preview":false}'
cf "/applications/$U/envs" -X POST  -d '{"key":"FOO","value":"bar","is_preview":false}'
```

Lifecycle:

```bash
cf "/applications/$U/restart" -X POST
cf "/applications/$U/stop"    -X POST
cf "/applications/$U/start"   -X POST
cf "/deploy?uuid=$U&force=false" -X POST     # trigger a deploy
```

## 4. Gotchas learned the hard way

- **Lifecycle endpoints are async.** The status returned right after `POST .../restart`
  is stale. Never call it evidence. Poll: `sleep 60-90`, then re-read
  `cf "/applications/$U" | jq -r .status` and re-read the logs. Require several
  consecutive healthy reads before declaring the app stable — a container that boots and
  aborts flaps through `healthy` between crashes.
- **`POST /applications/{uuid}/execute` (run a command in the container) is blocked by
  the Claude Code permission classifier.** Do not try to work around it. Hand the
  operator a `docker exec` command to run on the host instead.
- **Auto-deploy on push.** If the app watches a branch, `git push` to that branch _is_
  the deploy. Do not also trigger `/deploy` — you get two builds racing.
- **`git_branch` is authoritative** for which branch a push deploys. Confirm it before
  pushing anything.
- **Find the real host.** The app's target server is
  `cf "/applications/$U" | jq -r .destination.name` — often *not* the Coolify host and
  not whatever IP the operator remembers. Get it from the API before SSHing.

## 5. Volumes and data loss (read before touching a broken app)

`build_pack=dockercompose` apps get volumes namespaced `<app-uuid>_<volume-name>`.
On the app's host:

```bash
docker volume ls | grep -i <app-name>
docker inspect <container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
ls -la /var/lib/docker/volumes/<uuid>_<vol>/_data
```

**The failure mode to know:** a Docker named volume is deleted by
`docker volume prune` once no container references it. A crash-looping app leaves an
`exited` container; if a cleanup pass (Coolify's scheduled Docker cleanup, or a manual
`docker system prune`) removes that container first, the named volume becomes dangling
and the next prune wipes it. The app then boots on a fresh empty volume and looks fine.

Diagnostic: **if every file in the volume shares one recent mtime, the volume was
created then** — the data that predates it is gone, not hidden.

```bash
docker events --since 48h --filter type=volume | tail -40   # look for volume destroy
```

Prevention, and the change worth recommending: **use a host bind mount for state**, not
a named volume. Prune never touches a bind mount.

```yaml
services:
  app:
    volumes:
      - /data/<app>:/app/data      # instead of: app-data:/app/data
```

Plus `mkdir -p /data/<app> && chown -R <uid>:<gid> /data/<app>` on the host (uid must
match the container's user), and drop the entry from the top-level `volumes:` block.
Also verify a real backup schedule exists — a single `pre-migration` snapshot is not one.

## 6. Safety

- **Confirm with the operator before any state-changing call** on a production app:
  restart, stop, deploy, env edit. Approval for one restart is not approval for four.
- Before overwriting or deleting a database/state file, copy it aside first, with the
  container stopped so no WAL is in flight.
- Diagnosis is read-only: `/applications`, `/logs`, `/envs`, `/deployments`, `docker
  inspect`, `ls`. Exhaust those before mutating anything.
- Report evidence, not hypotheses. A log line or a byte count beats a theory.
