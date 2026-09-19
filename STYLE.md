# Plugin style

How to write QML and JS in this repo. Contract:
[Develop a Plugin](https://plugins.omarchy.org/develop.html).

Match `BarWidget.qml`, `Panel.qml`, `WeatherModel.qml`, and `Model.js` here. If you need a
pattern, copy first-party `omarchy.clock` or `omarchy.power`. Do not
invent a simpler widget or a parallel kit.

Stay in QML and JS. No C++ extension, no second Quickshell process, no
layers or files "for later."

## Split

| File | Role |
|---|---|
| `BarWidget.qml` | Manifest entry. Pill + `Loader` for the panel. Forwards `open` / `close` / `opened` / `popoutSwitchClosing`. |
| `Panel.qml` | Popup UI, focus, keyboard handling, and forwarding user actions. |
| `WeatherModel.qml` | Reactive weather state, fetching, retries, persistence, and search. It never references UI objects. |
| `Model.js` | Pure parse/format. No Qt types. `import "Model.js" as Model`. |

Views own focus, selection, and editor visibility. Nonvisual models own
data and workflow state; expose properties, action methods, and completion
signals. Pass values into model methods, never UI objects.

One `bar-widget`. The entry point loads `Panel.qml`; do not declare a
second `panel` kind. Same `moduleName` in both QML files, and it matches
`manifest.json` `id`. Imports are `qs.Commons` and `qs.Ui`. Host widgets
are `BarWidget`, `Panel`, `BarIconButton`.

`Bar.findPanelWidget` routes summon/hide through the bar-widget root.
Inject `bar`, `settings`, `anchorItem`, and `hostWidget` into the loaded
panel. Identify the popout as `hostWidget || root`.

`import "Model.js" as Model` only sees top-level functions. No `import` /
`export` in that file. No `import "root:/..."`.

## Theme

No hardcoded hex, RGB, or font families. Theme swaps must just work.

- Color: `Color.foreground`, `Color.background`, `Color.accent`, `Color.muted`, `root.bar.foreground`
- Type and space: `Style.font.*`, `Style.space(n)`, `Style.cornerRadius`
- Hover: `Style.hoverFillFor(root.bar.foreground, Color.accent)` and `Style.hoverStateColor(...)`
- Font: `root.bar.fontFamily`

Guard the bar: it is injected after the widget is created. Prefer a
binding over an imperative update. Prefer a Quickshell library
(`SystemClock`, `FileView`) over `Process`. When a process is required,
keep it in `WeatherModel.qml`, read it with `StdioCollector`, and parse it
with pure helpers in `Model.js`. Keep the last good value on a failed fetch.
Views must not reference model process or persistence objects directly.

Check a light theme and a dark theme before calling a UI change done.

## Comments

Comment only what the code cannot say: a non-obvious contract, a
workaround, or a why.

```qml
// Bar.findPanelWidget requires open/close/opened on the bar-widget root.
readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
```

## Tests

`mise check` is the default. Do not add a QML runner, screenshot tests,
or mocks unless a `Model.js` parse/format function is easy to get wrong
and cheap to assert. Test that function only.
