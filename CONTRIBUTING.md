# Contributing

This checkout is the live plugin (`~/.config/omarchy/plugins/wesgrimes.weather`).
GitHub repo: [wesleygrimes/omarchy-weather](https://github.com/wesleygrimes/omarchy-weather).
The plugin id is `wesgrimes.weather`.
Saved QML/JS reloads in the Omarchy shell; `mise dev` forces a rescan if it does not.

```bash
mise dev         # watch files and hot-reload Quickshell
mise screenshot  # open the popup; PNG lands in gitignored tmp/
mise check       # validate the plugin
```

Run `mise check` before every commit. Do not commit `tmp/`.

Plugin style: [STYLE.md](STYLE.md).

## Commits

[Conventional Commits](https://www.conventionalcommits.org/). Write for
a person. Header is required: imperative, lowercase, no period. Body is
why, one or two sentences. Skip the body when the header is enough. Do
not restate the header. Do not pad.

Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`.
`docs` is documentation only. The type matches the change. Do not use
`chore` or `style`. Scopes when they help: `panel`, `bar`, `scripts`,
`manifest`.

```
feat(panel): show feels-like next to the current temp

Keep the current temp as the hero; feels-like is secondary.
```

Not this:

```
feat(panel): show feels-like like we decided earlier

The first draft restated rules from chat and the old guide.
```

One logical change per commit. Two kinds of change are two commits.
No co-author or tool trailers. Someone who only read the README should
understand the message. Do not mention how the repo used to be, how the
change was made, or anything they would have to have been here to know.

## Pull requests

One change per PR. Title is Conventional Commits. The type matches the
work in the PR; `docs` only when the PR is documentation. Fill in
[.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md).
If this branch already has a pull request, update that one. Do not open
a second PR. Same PR may have more than one commit.

## Docs

Write for a person using the plugin. Short, present tense, current
behavior only. No history, no breadcrumbs, no pointers into the codebase.

## Listing

Listing is a GitHub issue on
[omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace).
Submit with the
[submit-plugin form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
Title: `[Plugin]: Weather`. Category: Widgets. Tags: Bar, Quickshell, and
suggest `weather` if a third tag helps.

## Contributors

Merged help is credited in the README with
[all-contributors](https://allcontributors.org). Do not edit the
contributors table or `.all-contributorsrc`. On the pull request, comment:

```text
@all-contributors please add @username for code
```

Use the right
[emoji key](https://allcontributors.org/docs/en/emoji-key) type
(`code`, `doc`, `bug`, `infra`, and so on).
