import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, run, window, keys, focused, hc, nextCommand } from "herdr";

const REPEAT_MS = 500;
const PREFIX_BINDINGS = [
  ["b", "Toggle sidebar", "layout.toggle", { id: "sidebar" }],
  ["c", "New tab", "tab.new"],
  ["N", "New space", "space.new"],
  ["v", "Split right", "pane.split", { direction: "right" }],
  ["%", "Split right", "pane.split", { direction: "right" }],
  ["-", "Split down", "pane.split", { direction: "down" }],
  ['"', "Split down", "pane.split", { direction: "down" }],
  ["x", "Close pane", "pane.close"],
  ["n", "Next tab", "tab.next"],
  ["p", "Previous tab", "tab.prev"],
  ["h", "Focus left", "pane.go", { direction: "left" }, true],
  ["j", "Focus down", "pane.go", { direction: "down" }, true],
  ["k", "Focus up", "pane.go", { direction: "up" }, true],
  ["l", "Focus right", "pane.go", { direction: "right" }, true],
  ["left", "Focus left", "pane.go", { direction: "left" }, true],
  ["down", "Focus down", "pane.go", { direction: "down" }, true],
  ["up", "Focus up", "pane.go", { direction: "up" }, true],
  ["right", "Focus right", "pane.go", { direction: "right" }, true],
  ["J", "Next space", "space.next"],
  ["K", "Previous space", "space.prev"],
  ["z", "Zoom pane", "pane.zoom"],
  ["d", "Minimize window", "window.minimize"],
  ["w", "Space/tab picker", "mod.open", { name: "picker" }],
  ...Array.from({ length: 10 }, (_, i) => [String(i), `Tab ${i === 0 ? 10 : i}`, "tab.select", { index: i === 0 ? 10 : i }]),
];

export default class WorkspaceStatus extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.leader = false;
    this.repeatGeneration = 0;
    this.terminal = null;
    this.pane = null;
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command !== "leader") continue;
        if (this.leader) this.sendPrefix(cx);
        else this.startLeader(cx);
      }
    });
  }

  startLeader(cx) {
    const target = focused();
    this.terminal = target?.terminal ?? null;
    this.pane = target?.pane ?? null;
    this.leader = true;
    this.handle.focus();
    this.repeatGeneration++;
    cx.notify();
  }

  endLeader(cx, restoreFocus = true) {
    this.leader = false;
    this.repeatGeneration++;
    cx.notify();
    if (restoreFocus && this.terminal) run("pane.focus", { terminal: this.terminal });
  }

  sendPrefix(cx) {
    const terminal = this.terminal;
    this.endLeader(cx, false);
    if (!terminal) return;
    const pending = hc(["keys", terminal, "ctrl+b"]);
    cx.spawn(async () => {
      const result = await pending;
      if (result.code !== 0) console.log(`kmdot-status: ${result.stderr}`);
    });
    run("pane.focus", { terminal });
  }

  handleLeaderKey(e, cx) {
    cx.stop_propagation();
    if (e.key === "escape") return this.endLeader(cx);
    const m = e.modifiers;
    if (m.control && e.key === "b") return this.sendPrefix(cx);
    const plain = !m.control && !m.alt && !m.platform;
    if (!plain) return this.endLeader(cx);
    let key = e.key_char ?? (m.shift && e.key.length === 1 ? e.key.toUpperCase() : e.key);
    if (m.shift && e.key === "5" && key !== "%") key = "%";
    if (key === "?") {
      this.endLeader(cx, false);
      return run("mod.open", { name: "kmdot-keybinds" });
    }
    const binding = PREFIX_BINDINGS.find(([bound]) => bound === key);
    if (!binding) return this.endLeader(cx);
    const [, , command, args = {}, repeatable = false] = binding;
    if (!repeatable) {
      this.endLeader(cx, false);
      if (command !== "window.minimize" && this.terminal) {
        run("pane.focus", { terminal: this.terminal });
      }
      run(command, args);
      return;
    }
    run(command, command === "pane.go" && this.pane ? { ...args, pane: this.pane } : args);
    const generation = ++this.repeatGeneration;
    cx.timer.after(REPEAT_MS, () => {
      if (this.repeatGeneration === generation && this.leader) this.endLeader(cx);
    });
    cx.notify();
  }

  // The palette key as actually bound, not a hardcoded one; without a
  // binding the hint stays useful ("commands") instead of lying.
  hint(t) {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+", option: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "app.palette");
    const parts = b && b.keys.endsWith("--") ? [...b.keys.slice(0, -2).split("-"), "-"] : b?.keys.split("-");
    const key = parts && parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join("");
    return key ? `${key}  commands` : "commands";
  }

  render() {
    const t = theme();
    const space = spaces().find(s => s.active);
    const list = agents();
    const needs = list.filter(a => a.status === "blocked").length;
    const label = (icon, text) => h_flex().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    const shortcuts = this.leader
      ? "Ctrl+B · b sidebar · c tab · n/p tabs · v/% right · -/\" down · h/j/k/l move · x close · ? keys · Esc cancel"
      : `${this.hint(t)}  ·  Ctrl+Alt+K  keybinds`;
    return h_flex().size_full().px(14).gap(16).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .track_focus(this.handle)
      .on_key_down((e, cx) => { if (this.leader) this.handleLeaderKey(e, cx); })
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), el => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} ${list.length === 1 ? "agent" : "agents"}`)
        .when(needs > 0, el => el.child(div().text_color(t.blocked).child(`· ${needs} ${needs === 1 ? "needs" : "need"} you`))))
      .child(div().flex_1())
      .child(div().id("palette").text_color(this.leader ? t.accent : t.dim)
        .when(!this.leader, el => el.on_click(() => run("app.palette")))
        .child(shortcuts));
  }
}
