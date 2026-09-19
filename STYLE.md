# Plugin style

How to build an Omarchy Quickshell plugin. This plugin stays a thin fork of
stock `omarchy.weather`. Clone the closest first-party popup and stay thin.
Stay in QML and JS. Do not add a C++ extension, a second Quickshell
process, or a parallel widget kit.

Ship the smallest change that matches vanilla Omarchy. Do not add layers,
helpers, IPC, or files "for later." Do not overfit to one machine, one
location, or one theme. If stock weather already has a way to do it, use
that.

Contract: [Develop a Plugin](https://plugins.omarchy.org/develop.html).
QML: [Quickshell introduction](https://quickshell.org/docs/guide/introduction/).

Copy from first-party `omarchy.clock`, `omarchy.weather`, and
`omarchy.power`. A thin third-party match:
[omarchy-geosphere-weather](https://github.com/ralfvb/omarchy-geosphere-weather).

## Runtime

Plugins share the long-lived `omarchy-shell` process and run unsandboxed.
Review every command and dependency.

A plugin is a public GitHub repo with one plugin and `manifest.json` at
the root. Install is clone plus validate: no build step, no install hook,
no sudo. Commit anything QML must load, including a generated `Model.js`.

The id cannot use `omarchy.*` and is permanent once listed. The repo
cannot contain published symlinks. Do not rewrite Omarchy or user config
unless the user asks. Optional root `preview.png` (or jpg / webp / avif).

The root README must have Install and Remove. Write down the license and
any extra dependencies.

## Manifest

`kinds` and `entryPoints` must agree. A bar pill with a popup is one
`bar-widget`. The entry point loads `Panel.qml`; do not declare a second
`panel` kind for that nested surface. Use the same `moduleName` in both
files.

```json
{
  "schemaVersion": 1,
  "id": "yourname.weather",
  "name": "Weather",
  "version": "1.0.0",
  "author": "Your name",
  "license": "MIT",
  "description": "Current weather on the bar with a forecast popup",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "Weather",
    "category": "Info",
    "allowMultiple": false,
    "defaultSection": "right"
  }
}
```

`allowMultiple` is false unless the widget is a spacer or indicator.

## Split

| File | Role |
|---|---|
| `BarWidget.qml` | Manifest entry. Pill + `Loader` for the panel. Forwards `open` / `close` / `opened` / `popoutSwitchClosing`. |
| `Panel.qml` | Popup UI and process I/O. |
| `Model.js` | Pure parse/format. No Qt types. `import "Model.js" as Model`. |

Imports are `qs.Commons` and `qs.Ui`. Host widgets are `BarWidget`, `Panel`,
`BarIconButton` / `WidgetButton`. A uppercase `.qml` file is a type.

`Bar.findPanelWidget` routes shell summon/hide through the bar-widget root,
not the nested panel. Inject `bar`, `settings`, `anchorItem`, and
`hostWidget` into the loaded panel. Identify the popout as
`hostWidget || root`.

```qml
BarWidget {
  id: root
  moduleName: "yourname.weather"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  Loader {
    id: panelLoader
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
  }

  BarIconButton {
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.label : ""
    slotSize: Style.bar.statusSlot
  }
}
```

```qml
Panel {
  id: root
  moduleName: "yourname.weather"
  manageIpc: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  KeyboardPanel {
    owner: root.barIdentity
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(240))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }
  }
}
```

```javascript
function parseLocationFile(raw) {
  // JSON in, plain object out. Panel.qml does not parse.
}
```

Some first-party widgets put the pill in `Panel.qml` and point
`entryPoints.barWidget` at that file. Use the split above for a popup.

## Theme

No hardcoded hex, RGB, or font families. Theme swaps must just work.

- Color: `Color.foreground`, `Color.background`, `Color.accent`, `Color.muted`, `root.bar.foreground`
- Type and space: `Style.font.*`, `Style.space(n)`, `Style.cornerRadius`
- Hover: `Style.hoverFillFor(root.bar.foreground, Color.accent)` and `Style.hoverStateColor(...)`
- Font: `root.bar.fontFamily`

Guard the bar: it is injected after the widget is created.

```qml
readonly property color foreground: bar ? bar.foreground : Color.foreground
readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
```

`barForeground` belongs to `Panel`, not `BarWidget`. Check a light theme
and a dark theme before calling a UI change done.

## QML

Prefer a binding over an imperative update. Prefer a Quickshell library
(`SystemClock`, `FileView`, `UPower`) over `Process`. When a process is
required, read it with `StdioCollector` and parse in `Model.js`. Keep the
last good value on a failed fetch.

`import "Model.js" as Model` only sees top-level functions. Do not use
`import` / `export` in that file. Do not use `import "root:/..."`.

## Comments

Comment only what the code cannot say: a non-obvious contract, a
workaround, or a why.

```qml
// Bar.findPanelWidget requires open/close/opened on the bar-widget root.
readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
```

## Tests

`mise check` (manifest validate) is the default. Do not add a QML runner,
screenshot tests, or mocks unless a `Model.js` parse/format function is
easy to get wrong and cheap to assert. Test that function only.
