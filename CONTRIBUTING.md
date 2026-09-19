# Contributing

This checkout is the live plugin (`~/.config/omarchy/plugins/wesgrimes.weather`).
Saved QML/JS reloads in the Omarchy shell; `mise dev` forces a rescan if it does not.

```bash
mise dev         # watch files and hot-reload Quickshell
mise screenshot  # open the popup; PNG lands in gitignored tmp/
mise check       # validate the plugin
```

`mise tasks` lists jobs. Run `mise check` before every commit.

Do not commit `tmp/`. Screenshots and other local scratch stay there.

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/) strictly.

```
<type>(<scope>): <short summary>

<body>

<footer>
```

The header is required. The body is required except for `docs` (and must be at least 20 characters when present). The footer is optional.

### Header

```
<type>(<scope>): <short summary>
```

- `type` is required; `scope` is optional
- summary is imperative present tense: "add" not "added" or "adds"
- do not capitalize the first letter
- no period at the end

**Types** (only these):

| Type | Use for |
|---|---|
| `feat` | a new feature |
| `fix` | a bug fix |
| `perf` | a performance improvement |
| `refactor` | a change that is neither a fix nor a feature |
| `test` | adding or correcting tests |
| `docs` | documentation only |
| `build` | build system, mise tasks, scripts, dependencies |
| `ci` | CI configuration |

Do not use `chore`, `style`, or other aliases.

**Scopes** when they help: `panel`, `bar`, `scripts`, `manifest`. Omit the scope when the change is repo-wide.

```
feat(panel): show feels-like next to the current temp

fix(bar): hide the pill when the label is empty

docs: describe mise screenshot

build(scripts): write captures under tmp/
```

### Body

Explain why, in the imperative present tense. Do not list files.

### Footer

Breaking changes and issue references go here:

```
BREAKING CHANGE: <summary>

<description and migration>

Fixes #123
```

A revert starts with `revert: ` plus the original header. The body must include `This reverts commit <sha>.` and why.

One logical change per commit. No co-author or tool trailers.

## Pull requests

One change per PR. Title is Conventional Commits, same as the commit.
The body is for a person: what changed and how to try it. Not a file list,
not a tour of the repo, not a recap of how we got here.

## Docs

Write for a person using the plugin. Short, present tense, current behavior
only. No history, no breadcrumbs, no pointers into the codebase.

Plugin style: [STYLE.md](STYLE.md).

## Listing

Listing is a GitHub issue on
[omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace).
A bot checks the current commit; a maintainer then approves. That is a
listing review, not a security audit. Plugins stay unsandboxed.

Submit with the
[submit-plugin form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
Title: `[Plugin]: Weather`. Category: Widgets. Tags: Bar, Quickshell, and
suggest `weather` if a third tag helps.

## Contributors

Merged help is credited in the README with
[all-contributors](https://allcontributors.org). On a pull request or issue,
comment:

```text
@all-contributors please add @username for code
```

Use the right
[emoji key](https://allcontributors.org/docs/en/emoji-key) type
(`code`, `doc`, `bug`, `infra`, and so on). The bot opens a small follow-up
pull request that updates the contributor table.

