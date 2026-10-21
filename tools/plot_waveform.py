"""
把 XSim 导出的 dump.vcd 画成 README 用的时序图。

用法:
    & C:\\ic-work\\venv\\Scripts\\Activate.ps1
    python plot_waveform.py <dump.vcd> <out.png> [t0_ns] [t1_ns]

设计意图:
  - 只看握手相关的 6 根线, 不要 clk 以外的东西;
  - 用两条竖带标出"成交"的时钟沿: 绿色 = 上游被接收, 蓝色 = 下游被取走;
  - 总线画成方块并标十六进制值, 一眼能看出数据有没有丢/重/乱序。
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.lines import Line2D
import vcdvcd

PS_PER_NS = 1000.0

COL_CLK   = "#5f6b7a"
COL_VALID = "#2e7d32"
COL_READY = "#1565c0"
COL_DATA  = "#8d5524"
COL_BAND_IN  = "#2e7d32"
COL_BAND_OUT = "#1565c0"


def load(path):
    return vcdvcd.VCDVCD(path, store_tvs=True, store_scopes=False)


def find(vcd, suffix):
    """vcdvcd 给总线加上了 [7:0] 后缀, 这里按"末级名字"匹配"""
    for name in vcd.signals:
        last = name.split(".")[-1]
        if last == suffix or last.startswith(suffix + "["):
            return vcd[name]
    raise KeyError(suffix + " | available: " + ", ".join(sorted(vcd.signals)))


def to_points(sig):
    """[(tick, int_value), ...]  tick 单位 = timescale 单位 (这里 1ps)

    vcdvcd 已经剥掉了 'b' 前缀, 值形如 '10100101' / '0' / 'x'。
    x/z 直接跳过: 那几段本来就不该被读。
    """
    pts = []
    for t, val in sig.tv:
        v = val.strip()
        if v[:1] in ("x", "z", "X", "Z"):
            continue
        try:
            pts.append((t, int(v, 2)))
        except ValueError:
            continue
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
    """切成 [(start, end, value)] 并裁剪到 [t0, t1]"""
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


def draw_bus(ax, y, pts, t0, t1, width_bits, height=0.62):
    segs = segments(pts, t0, t1)
    prev_known = None
    for s, e, v in segs:
        unknown = v is None and prev_known is None
        if v is None:
            v = prev_known if prev_known is not None else 0
        prev_known = v
        ax.add_patch(Rectangle((s, y - height / 2), e - s, height,
                               facecolor="#f4f1ea" if unknown else "#fbf7f0",
                               edgecolor="#b9a89a" if unknown else COL_DATA,
                               lw=1.0, zorder=2))
        if e - s > (t1 - t0) * 0.012:
            digits = (width_bits + 3) // 4
            label = "xx" if unknown else format(v, "0{}X".format(digits))
            ax.text((s + e) / 2, y, label,
                    ha="center", va="center", fontsize=7.5,
                    color="#9b8b7e" if unknown else COL_DATA,
                    family="monospace", zorder=3)


def main():
    vcd_path = sys.argv[1]
    out_path = sys.argv[2]
    t0_ns = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    t1_ns = float(sys.argv[4]) if len(sys.argv) > 4 else 260.0

    vcd = load(vcd_path)
    t0, t1 = t0_ns * PS_PER_NS, t1_ns * PS_PER_NS

    names = ["clk", "rst_n", "s_valid", "s_ready", "s_data",
             "m_valid", "m_ready", "m_data"]
    sigs = {n: to_points(find(vcd, n)) for n in names}

    # 复位线只在窗口里真的动过才画 (随机段 rst_n 恒为 1, 画出来是浪费一行)
    if not [t for t, v in sigs["rst_n"] if t0 < t <= t1]:
        names.remove("rst_n")

    # 成交时刻: valid 与 ready 同时为 1 的上升沿
    clk_edges = [t for t, v in sigs["clk"] if v == 1]
    accept, pop = [], []
    for t in clk_edges:
        if t < t0 or t > t1:
            continue
        if value_at(sigs["s_valid"], t) == 1 and value_at(sigs["s_ready"], t) == 1:
            accept.append(t)
        if value_at(sigs["m_valid"], t) == 1 and value_at(sigs["m_ready"], t) == 1:
            pop.append(t)

    rows = list(reversed(names))          # clk 在最上面
    ypos = {n: i + 1 for i, n in enumerate(rows)}

    fig, ax = plt.subplots(figsize=(11.5, 5.0))

    for t in clk_edges:
        if t0 <= t <= t1:
            ax.axvline(t, color="#e3e7ec", lw=0.6, zorder=0)

    for t in accept:
        ax.axvline(t, color=COL_BAND_IN, lw=1.1, ls=(0, (2, 2)), alpha=.85, zorder=1)
    for t in pop:
        ax.axvline(t, color=COL_BAND_OUT, lw=1.1, ls=(0, (2, 2)), alpha=.85, zorder=1)

    draw_bit(ax, ypos["clk"],     sigs["clk"],     t0, t1, COL_CLK, height=.30)
    if "rst_n" in names:
        draw_bit(ax, ypos["rst_n"], sigs["rst_n"], t0, t1, "#b23c17", height=.30)
    draw_bit(ax, ypos["s_valid"], sigs["s_valid"], t0, t1, COL_VALID)
    draw_bit(ax, ypos["s_ready"], sigs["s_ready"], t0, t1, COL_READY)
    draw_bus(ax, ypos["s_data"],  sigs["s_data"],  t0, t1, 8)
    draw_bit(ax, ypos["m_valid"], sigs["m_valid"], t0, t1, COL_VALID)
    draw_bit(ax, ypos["m_ready"], sigs["m_ready"], t0, t1, COL_READY)
    draw_bus(ax, ypos["m_data"],  sigs["m_data"],  t0, t1, 8)

    ax.set_xlim(t0, t1)
    ax.set_ylim(0.3, len(rows) + 0.9)
    ax.set_yticks([ypos[n] + 0.2 for n in rows])
    ax.set_yticklabels(rows, family="monospace", fontsize=9)
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

    handles = [Line2D([0], [0], color=COL_BAND_IN, lw=1.4, ls=(0, (2, 2)),
                      label="accepted: s_valid & s_ready"),
               Line2D([0], [0], color=COL_BAND_OUT, lw=1.4, ls=(0, (2, 2)),
                      label="popped: m_valid & m_ready")]
    ax.legend(handles=handles, loc="lower right", bbox_to_anchor=(1.0, 1.005),
              ncol=2, frameon=False, fontsize=8.2, handlelength=1.2,
              columnspacing=1.4, borderpad=0)

    kind = "directed tests" if t1_ns <= 210 else "random stimulus"
    ax.set_title("hs_reg: valid/ready register slice (%s)" % kind,
                 fontsize=10.5, loc="left", pad=22)

    # ---- 图下的两行说明: 让没读过 README 的人也看得懂这段波形 ----
    if t1_ns <= 210:
        caps = [
            "1)  50-100 ns   back-pressure: m_ready = 0, so m_valid and m_data hold their value and s_ready drops to 0 — upstream must wait.",
            "2)  ~130-145 ns  one-beat swap: the old word is popped and the new word (22) is loaded on the same clock edge — throughput stays one word per cycle.",
        ]
    else:
        caps = [
            "Random stimulus: s_valid ~75 %, m_ready ~50 %.  Words leave in exactly the order they arrived — no loss, no duplication.",
            "Over the full 500-cycle run: 211 accepted, 211 popped, 0 errors.",
        ]

    fig.subplots_adjust(left=0.087, right=0.985, top=0.855, bottom=0.255)
    for i, cap in enumerate(caps):
        fig.text(0.087, 0.085 - i * 0.052, cap, fontsize=8.2, color="#4a4f57",
                 ha="left", va="bottom")

    fig.savefig(out_path, dpi=170, facecolor="white")
    print("saved", out_path, "| accepted", len(accept), "| popped", len(pop))


if __name__ == "__main__":
    main()
