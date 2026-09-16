---
description: Bump nginx (and every module pinned with it) on its MAJOR.MINOR branch, then build and verify it
argument-hint: "[MAJOR.MINOR]  e.g. 1.28 — omit to discover the newest series"
allowed-tools: Bash, Read, Edit, Glob, Grep
---

# Bump nginx to the newest shippable version

Argument: `$ARGUMENTS` (a `MAJOR.MINOR` series, or empty for "newest overall").

## The constraint that drives everything

The newest nginx is usually **not** shippable here. This image installs the
**prebuilt** `ngx_otel_module.so` from nginx.org's Alpine repo, and nginx
refuses to load a dynamic module whose version differs from its own
(`src/core/ngx_module.c`); `--with-compat` does not exempt that check. So:

- `NGINX_VERSION` must exactly equal a version with an `nginx-module-otel` apk
  built for **both** `x86_64` and `aarch64` (we publish both).
- `FROM alpine:X.Y` must be the Alpine release that apk was built against.
- `GPG_KEYS` must be whoever signed *that* release. nginx rotates signers —
  1.28.3 is arut, 1.30.5 is pluknet. Never carry it over from the last bump.

nginx.org's Alpine repo only packages otel for the **stable** series — 1.26,
1.28, 1.30. Mainline (1.27, 1.29, 1.31) has no otel apk at all, so those
series cannot be bumped; `bin/nginx-latest.sh` reports which series exist and
exits non-zero. That is why `master` never followed branch `1.27`.

The otel apk also drags in runtime libraries of its own — 0.1.0 (nginx 1.26.x)
needed only c-ares/libstdc++/zlib, 0.1.2 (nginx 1.28+) links grpc, protobuf and
abseil. The Dockerfile resolves whatever the apk's `.PKGINFO` declares, so this
is handled, but it is why the `nginx -t` load check matters: a module can be the
right version and still fail to `dlopen`.

`headers-more`, `fancyindex` and the substitutions filter are compiled from
source, so no index can tell you whether they fit — only `./configure && make`
can. They are bumped separately and validated by the build.

## Procedure

### 1. Discover the target versions

Refuse to start if the working tree is dirty — show `git status` and stop.

```bash
./bin/nginx-latest.sh $ARGUMENTS
```

It prints sourceable `KEY=value` lines plus a `NGINX_CANDIDATES` fallback
ladder (newest first). This runs **before** picking a branch, because with no
argument the branch name is not known until the newest version is discovered.

### 2. Pick the branch

Every series lives on its own `MAJOR.MINOR` branch — `1.25`, `1.26`, `1.27`
are each pinned to their series and diverged from `master`. **The work always
happens on such a branch, never directly on `master`.**

Take the series from the `NGINX_VERSION` just discovered — so `1.30.5` means
branch `1.30`, whether the user named the series or not.

Every branch is based on `master`, so bring `master` up to date first:

```bash
git fetch origin
git switch master && git merge --ff-only origin/master
```

Being *ahead* of `origin/master` is fine — that is unpushed local work. Being
*diverged* is not: stop and report rather than merging or rebasing `master`.

Then, with `<series>` taken from the discovered `NGINX_VERSION`:

- **branch does not exist** → `git checkout -b <series> master`
- **branch exists** (locally or on `origin`) → check it out and back-merge, so
  the series picks up structural fixes made since it was cut:

  ```bash
  git checkout <series>
  git merge master
  ```

  This normally auto-merges — the version pins sit on different lines from the
  structural changes, so merging `master` into `1.27` keeps `1.27.1` and still
  gains the otel rework. If it does conflict, keep master's structure and the
  branch's version pins; the pins are overwritten in step 3 anyway. A conflict
  anywhere *else* is a signal — stop and show the user.

Then read the current pins out of that branch's `Dockerfile` and show the user
a before/after table. If nothing moved, say so and stop.

### 3. Bump the nginx-coupled pins first, alone

Change only these four, together — they are one atomic unit:

| Line | From | To |
|---|---|---|
| `FROM alpine:` | current | `ALPINE_VERSION` |
| `ENV NGINX_VERSION=` | current | `NGINX_VERSION` |
| `ENV MODULE_URL_BASE=` | current | `MODULE_URL_BASE` |
| `GPG_KEYS=` | current | `GPG_KEYS` |

Then build and verify (step 5).

**If the build fails**, read the log before reacting:
- GPG verify failed → the key is wrong; re-read it from the `.asc`.
- No matching otel apk → `nginx-latest.sh` and the Dockerfile disagree; stop
  and report, do not paper over it.
- `dlopen() ... failed (Error loading shared library ...)` → the otel apk gained
  a dependency the `.PKGINFO` resolution did not cover. Report it; do not
  hardcode a package name to get past it.
- A module failed to **compile** → this nginx is too new for a from-source
  module. Step down to the next entry in `NGINX_CANDIDATES`, re-run
  `bin/nginx-latest.sh` for that series to get its own Alpine and GPG key, and
  retry. Report which version you landed on and why.

Do not try more than three rungs of the ladder without checking in.

### 4. Then bump the from-source modules, one at a time

`MORE_SET_HEADER_VERSION`, `FANCYINDEX`, `SUBS_FILTER_COMMIT`. Build and verify
after **each** one, so a failure names the culprit. If one breaks the build,
revert that single pin, leave the others bumped, and report it — do not step
nginx down to accommodate a third-party module.

### 5. Verify — the build is only half the gate

The Dockerfile already fails the build if the otel apk does not match
`NGINX_VERSION`, and runs `nginx -t` with `load_module ngx_otel_module.so`.
On top of that, actually run the thing:

```bash
docker build -t nginx-xtras-bump:test .
docker run -d --rm --name nginx-xtras-bump -p 18080:80 nginx-xtras-bump:test
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:18080/     # expect 200
docker exec nginx-xtras-bump nginx -v                                   # expect the new version
docker exec nginx-xtras-bump sh -c \
  'printf "load_module modules/ngx_otel_module.so;\nevents {}\nhttp {}\n" > /tmp/o.conf && nginx -t -c /tmp/o.conf'
docker stop nginx-xtras-bump
```

The `curl` alone proves nothing about otel — the shipped config never loads it.
The `nginx -t` line is the real compatibility check; never skip it.

### 6. Documentation

If this is a new `MAJOR.MINOR` series, add it to the `## Tags` list in
`README.md` (newest first). Leave the `latest` marker alone unless the user
says this series is becoming the new latest — that is a promotion decision,
not part of a bump.

### 7. Stop and report

Print `git diff`, plus:
- the branch worked on, and whether it was created or already existed;
- the version landed on, and — if it is not the newest nginx release — which
  component capped it and at what version;
- any module pin deliberately left behind, and the error that caused it;
- the verification output.

`master` is not touched by this command, and neither is the `x.y` git tag that
triggers the versioned CI build. Promoting a series to `master` or tagging a
release is the user's call, made after reviewing the branch.

**Never `git add`, `git commit`, `git push`, or open a PR.** Hand the diff to
the user and wait. This holds even if the change looks trivial.
