# Contributing

This repository follows Git Flow, Conventional Commits and Semantic Versioning.

## Branches

| Branch | Created from | Merges into | Purpose |
|--------|--------------|-------------|---------|
| `main` | — | — | Releases only. Every merge commit on it is a tagged release |
| `develop` | `main` | — | Integration branch for the next release |
| `feature/<topic>` | `develop` | `develop` | One batch of work, for example `feature/networking` |
| `release/<version>` | `develop` | `main`, then back into `develop` | Stabilises a release, for example `release/0.3.0` |
| `hotfix/<version>` | `main` | `main`, then back into `develop` | Urgent fix to a released version, for example `hotfix/1.0.1` |

Rules:

- Changes reach `main` and `develop` through pull requests only.
- Pull requests are merged with a merge commit. Squash and rebase merges are not used,
  so the individual commits of a branch stay visible in history.
- A pull request into `main` comes from `release/*` or `hotfix/*`. A pull request into
  `develop` comes from `feature/*`, `release/*` or `hotfix/*`.

## Commits

Commit subjects follow [Conventional Commits](https://www.conventionalcommits.org/)
with a mandatory scope:

```
type(scope): lowercase imperative summary
```

| Type | Use for |
|------|---------|
| `feat` | New infrastructure or capability |
| `fix` | Correction of a defect |
| `docs` | Documentation only |
| `refactor` | Restructuring with no behaviour change |
| `ci` | Pipeline changes |
| `build` | Tooling and dependencies |
| `chore` | Repository housekeeping |

Scopes name the area touched: a module (`networking`, `security`, `compute`, `data`,
`messaging`, `edge`, `registry`, `observability`, `irsa-role`), a part of the root
(`root`, `bootstrap`, `environments`), or a document or tool (`readme`, `architecture`,
`diagram`, `changelog`, `contributing`, `github`, `gitignore`, `quality`, `release`).
`quality` is the local quality gate: the `Makefile` and the check scripts it runs.

Each commit does one thing and leaves the repository valid. The last commit of a
feature branch updates the changelog.

## Pull requests

A pull request delivers one batch of related work. Its description states:

- **Summary**: what the batch adds.
- **Knowledge consolidated**: the concepts this batch puts into practice.
- **Decisions and why**: each choice that had a real alternative, and the reason.
- **Verification**: the commands run and their result.
- **Out of scope**: what was deliberately left for a later batch.

## Versions and changelog

- Versions follow [Semantic Versioning](https://semver.org/). Before `1.0.0`, each
  release is a minor version.
- [`CHANGELOG.md`](CHANGELOG.md) follows
  [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Feature branches add
  entries under `Unreleased`.

## Releasing

1. Create `release/<version>` from `develop`.
2. Commit `chore(release): <version>`, which moves the `Unreleased` entries under a
   dated version heading.
3. Open a pull request into `main` and merge it with a merge commit.
4. Tag the merge commit: `git tag -a v<version> -m "v<version>: <summary>"`.
5. Open a pull request from `release/<version>` into `develop` to carry the release
   commit back.

A hotfix follows the same steps, starting from `main` on a `hotfix/<version>` branch.
