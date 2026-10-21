"""
把 XSim 导出的 dump.vcd 画成 README 用的时序图。

用法:
    python plot_waveform.py <dump.vcd> <out.png> <profile> <t0_ns> <t1_ns>

    profile: hs (握手寄存器) | fifo (同步 FIFO) | lif (泄漏累加器)

设计意图:
  - 每个模块只看它自己的几根关键线, 不要一屏 20 根;
  - 用竖直虚线标出"这一拍真的发生了什么"(成交/写入/读出/更新);
  - 总线画成方块并标数值 (hex / 无符号 dec / 有符号 dec), 一眼看出数据有没有丢/重/乱序;
  - 图下面两行说明, 让没读过 README 的人也看得懂。
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.lines import Line2D
import vcdvcd

PS_PER_NS = 1000.0

GREEN = "#2e7d32"
BLUE = "#1565c0"
RED = "#b23c17"
BROWN = "#8d5524"
PURPLE = "#6a3d9a"
GRAY = "#5f6b7a"


# --------------------------------------------------------------------------
# 每个模块一张"配方": 画哪些行、什么颜色、怎么格式化、标哪些事件
# --------------------------------------------------------------------------
def hs_captions(t0, t1):
    if t1 <= 210:
        return [
            "1)  50-100 ns   back-pressure: m_ready = 0, so m_valid and m_data hold their value and s_ready drops to 0 — upstream must wait.",
            "2)  ~130-145 ns  one-beat swap: the old word is popped and the new word (22) is loaded on the same clock edge — throughput stays one word per cycle.",
        ]
    return [
        "Random stimulus: s_valid ~75 %, m_ready ~50 %.  Words leave in exactly the order they arrived — no loss, no duplication.",
        "Over the full 500-cycle run: 211 accepted, 211 popped, 0 errors.",
    ]


def fifo_captions(t0, t1):
    if t0 > 2800:
        return [
            "Every clock edge in this window has wr_en and rd_en high at the same time (the queue is neither full nor empty).",
            "count stays at 4: the +1 and the -1 cancel out. Two sequential 'if' statements would silently apply only the last one.",
        ]
    if (t1 - t0) > 400:
        return [
            "count fills 0 -> 5, drains back to 0 (empty = 1), then refills to 16 (full = 1). dout is a combinational read: it already shows the head.",
            "While full = 1 the wr_en pulses are ignored (din = EE never enters); while empty = 1, dout keeps its last value (0E).",
        ]
    if t0 > 500:
        return [
            "The queue fills up: count climbs to 16 and full goes high.",
            "While full = 1 the wr_en pulses are ignored — din = EE never enters, count stays 16 until a read frees a slot.",
        ]
    return [
        "dout is a combinational read (first-word-fall-through): whenever count > 0 it already shows the head of the queue.",
        "count rises on each accepted write and falls on each accepted read; once empty = 1, dout keeps its last value (0E).",
    ]


def fifo_title(t0, t1):
    if t0 > 2800:
        return "simultaneous read & write"
    if (t1 - t0) > 400:
        return "fill, drain, full"
    if t0 > 500:
        return "filling up to full"
    return "write, read, empty"


def lif_captions(t0, t1):
    return [
        "en = 0 means the register is not written: i_in swings +999 / -999 and v_out does not move at all — the event-driven saving.",
        "en = 1: v_out <= v_out - (v_out >>> 4) + i_in. With i_in = 0 it decays 224 -> 210 -> 197 -> ... exactly beta = 15/16 per step.",
    ]


PROFILES = {
    "hs": {
        "title": "hs_reg: valid/ready register slice",
        "subtitle": lambda t0, t1: "directed tests" if t1 <= 210 else "random stimulus",
        "rows": [
            ("clk", "bit", GRAY), ("rst_n", "bit", RED),
            ("s_valid", "bit", GREEN), ("s_ready", "bit", BLUE),
            ("s_data", "hex", BROWN), ("m_valid", "bit", GREEN),
            ("m_ready", "bit", BLUE), ("m_data", "hex", BROWN),
        ],
        "events": [
            ("accepted: s_valid & s_ready", GREEN,
             lambda v: v.get("s_valid") == 1 and v.get("s_ready") == 1),
            ("popped: m_valid & m_ready", BLUE,
             lambda v: v.get("m_valid") == 1 and v.get("m_ready") == 1),
        ],
        "captions": hs_captions,
    },
    "fifo": {
        "title": "fifo: synchronous 8b x 16 event queue",
        "subtitle": fifo_title,
        "rows": [
            ("clk", "bit", GRAY), ("rst_n", "bit", RED),
            ("wr_en", "bit", GREEN), ("din", "hex", BROWN),
            ("full", "bit", RED), ("count", "dec", PURPLE),
            ("rd_en", "bit", BLUE), ("dout", "hex", BROWN),
            ("empty", "bit", RED),
        ],
        "events": [
            ("write accepted: wr_en & ~full", GREEN,
             lambda v: v.get("wr_en") == 1 and v.get("full") == 0),
            ("read accepted: rd_en & ~empty", BLUE,
             lambda v: v.get("rd_en") == 1 and v.get("empty") == 0),
        ],
        "captions": fifo_captions,
    },
    "lif": {
        "title": "lif_leak: leaky membrane potential accumulator (beta = 15/16)",
        "subtitle": lambda t0, t1: "event-driven update",
        "rows": [
            ("clk", "bit", GRAY), ("rst_n", "bit", RED),
            ("en", "bit", GREEN), ("i_in", "sdec", BROWN),
            ("v_out", "sdec", PURPLE),
        ],
        "events": [
            ("updated: en = 1", GREEN, lambda v: v.get("en") == 1),
        ],
        "captions": lif_captions,
    },
}


def load(path):
    return vcdvcd.VCDVCD(path, store_tvs=True, store_scopes=False)


def find(vcd, suffix):
    """vcdvcd 给总线加上了 [7:0] 后缀, 这里按"末级名字"匹配"""
    for name in vcd.signals:
        last = name.split(".")[-1]
        if last == suffix or last.startswith(suffix + "["):
            return vcd[name]
    raise KeyError(suffix + " | available: " + ", ".join(sorted(vcd.signals)))


def to_points(sig, width):
    """[(tick, int_value)]  tick 单位 = timescale 单位 (这里 1ps)

    vcdvcd 已经剥掉了 'b' 前缀; x/z 段跳过不画。
    有符号信号在这里就按补码解释成负数, 后面才能正确显示。
    """
    pts = []
    for t, val in sig.tv:
        v = val.strip()
        if v[:1] in ("x", "z", "X", "Z"):
            continue
        try:
            iv = int(v, 2)
        except ValueError:
            continue
        if width and iv >= (1 << (width - 1)) and width > 1:
            iv -= (1 << width)
        pts.append((t, iv))
    return pts


def value_at(pts, t):
    cur = None
    for tt, vv in pts:
        if tt <= t:
            cur = vv
        else:
            break
    return cur


def segments(pts, t0, t1):
    if not pts:
        return []
    out = []
    for i, (t, v) in enumerate(pts):
        end = pts[i + 1][0] if i + 1 < len(pts) else t1
        s, e = max(t, t0), min(end, t1)
        if e > s:
            out.append((s, e, v))
    if pts[0][0] > t0:
        out.insert(0, (t0, min(pts[0][0], t1), None))
    return out


def fmt_bus(v, kind, width):
    if kind == "hex":
        return format(v & ((1 << width) - 1), "0{}X".format((width + 3) // 4))
    if kind == "dec":
        return str(v)
    if kind == "sdec":
        return ("+" if v > 0 else "") + str(v)
    return str(v)


def draw_bit(ax, y, pts, t0, t1, color, height=0.42):
    for s, e, v in segments(pts, t0, t1):
        if v == 1:
            ax.plot([s, e], [y + height, y + height], color=color, lw=2.2,
                    solid_capstyle="butt")
            ax.plot([s, s], [y, y + height], color=color, lw=1.0, alpha=.55)
        else:
            ax.plot([s, e], [y, y], color=color, lw=1.4, alpha=.9,
                    solid_capstyle="butt")
        ax.plot([e, e], [y, y + (height if v == 1 else 0)],
                color=color, lw=1.0, alpha=.55)


def draw_bus(ax, y, pts, t0, t1, kind, width, height=0.62):
    segs = segments(pts, t0, t1)
    prev_known = None
    for s, e, v in segs:
        unknown = v is None and prev_known is None
        if v is None:
            v = prev_known if prev_known is not None else 0
        prev_known = v
        ax.add_patch(Rectangle((s, y - height / 2), e - s, height,
                               facecolor="#f4f1ea" if unknown else "#fbf7f0",
                               edgecolor="#b9a89a" if unknown else BROWN,
                               lw=1.0, zorder=2))
        if e - s > (t1 - t0) * 0.012:
            label = "xx" if unknown else fmt_bus(v, kind, width)
            ax.text((s + e) / 2, y, label,
                    ha="center", va="center", fontsize=7.5,
                    color="#9b8b7e" if unknown else BROWN,
                    family="monospace", zorder=3)


def main():
    vcd_path, out_path, profile = sys.argv[1], sys.argv[2], sys.argv[3]
    t0_ns = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
    t1_ns = float(sys.argv[5]) if len(sys.argv) > 5 else 260.0

    prof = PROFILES[profile]
    vcd = load(vcd_path)
    t0, t1 = t0_ns * PS_PER_NS, t1_ns * PS_PER_NS

    rows = list(prof["rows"])
    sigs, widths = {}, {}
    for name, kind, _c in rows:
        sig = find(vcd, name)
        widths[name] = int(sig.size) if kind != "bit" else 1
        sigs[name] = to_points(sig, widths[name] if kind == "sdec" else None)

    # 复位线只在窗口里真的动过才画
    if not [t for t, v in sigs["rst_n"] if t0 < t <= t1]:
        rows = [r for r in rows if r[0] != "rst_n"]

    clk_edges = [t for t, v in sigs["clk"] if v == 1]
    marks = {label: [] for label, _c, _f in prof["events"]}
    for t in clk_edges:
        if t < t0 or t > t1:
            continue
        vals = {n: value_at(sigs[n], t) for n in sigs}
        for label, _c, test in prof["events"]:
            try:
                if test(vals):
                    marks[label].append(t)
            except Exception:
                pass

    ypos = {name: i + 1 for i, (name, _k, _c) in enumerate(reversed(rows))}

    fig, ax = plt.subplots(figsize=(11.5, 5.0))
    for t in clk_edges:
        if t0 <= t <= t1:
            ax.axvline(t, color="#e3e7ec", lw=0.6, zorder=0)
    for label, color, _f in prof["events"]:
        for t in marks[label]:
            ax.axvline(t, color=color, lw=1.1, ls=(0, (2, 2)), alpha=.85, zorder=1)

    for name, kind, color in rows:
        if kind == "bit":
            draw_bit(ax, ypos[name], sigs[name], t0, t1, color,
                     height=.30 if name in ("clk", "rst_n") else .42)
        else:
            draw_bus(ax, ypos[name], sigs[name], t0, t1, kind, widths[name])

    ax.set_xlim(t0, t1)
    ax.set_ylim(0.3, len(rows) + 0.9)
    ax.set_yticks([ypos[n] + 0.2 for n, _k, _c in rows])
    ax.set_yticklabels([n for n, _k, _c in rows], family="monospace", fontsize=9)
    ax.set_xlabel("time (ns)")

    span = t1_ns - t0_ns
    step = 20 if span <= 320 else 50
    tick_ns = list(range(int(t0_ns), int(t1_ns) + 1, step))
    ax.set_xticks([v * PS_PER_NS for v in tick_ns])
    ax.set_xticklabels([str(v) for v in tick_ns], fontsize=8)
    ax.tick_params(axis="x", length=3)
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.grid(axis="x", visible=False)

    handles = [Line2D([0], [0], color=c, lw=1.4, ls=(0, (2, 2)), label=lbl)
               for lbl, c, _f in prof["events"]]
    ax.legend(handles=handles, loc="lower right", bbox_to_anchor=(1.0, 1.005),
              ncol=len(handles), frameon=False, fontsize=8.2, handlelength=1.2,
              columnspacing=1.4, borderpad=0)

    kind = prof["subtitle"](t0_ns, t1_ns)
    ax.set_title("%s (%s)" % (prof["title"], kind), fontsize=10.5, loc="left", pad=22)

    fig.subplots_adjust(left=0.087, right=0.985, top=0.855, bottom=0.255)
    for i, cap in enumerate(prof["captions"](t0_ns, t1_ns)):
        fig.text(0.087, 0.085 - i * 0.052, cap, fontsize=8.2, color="#4a4f57",
                 ha="left", va="bottom")

    fig.savefig(out_path, dpi=170, facecolor="white")
    total = max(t for t, _v in sigs["clk"]) / PS_PER_NS
    print("saved %s | run length %.0f ns | marks: %s" %
          (out_path, total, {k: len(v) for k, v in marks.items()}))


if __name__ == "__main__":
    main()
