"""Figures for the TurAIsta paper.

Every value is copied from a notebook output; the comment beside it names the cell.
Run: uv run --with matplotlib python paper/figures/make_figures.py
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Polygon

OUT = Path(__file__).parent
ACCENT = "#1f5fa8"
INK = "#222222"
QUIET = "#666666"
GREY = "#9a9a9a"
LIGHT = "#e6e6e6"

plt.rcParams.update({
    "font.family": "Times New Roman",
    "mathtext.fontset": "stix",
    "font.size": 10,
    "axes.titlesize": 10,
    "axes.titleweight": "bold",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.05,
})


def save(fig, name):
    fig.savefig(OUT / name)
    plt.close(fig)
    print("wrote", name)


# Figure 1: flowchart for one guest message (README.md "Message inquiry"; lib/core).
# Standard symbols: terminator = start/end, parallelogram = input, rectangle = process,
# diamond = decision. The accent marks the path a safety question takes.
def fig1():
    fig, ax = plt.subplots(figsize=(6.6, 6.9))
    ax.set_xlim(0, 12.0)
    ax.set_ylim(0.0, 11.0)
    ax.set_aspect("equal")
    ax.axis("off")
    pw, ph = 2.6, 0.9      # process box
    dw, dh = 1.35, 0.7     # decision half-width, half-height

    def style(accent):
        return dict(facecolor=ACCENT if accent else "white",
                    edgecolor=ACCENT if accent else INK, linewidth=1.3 if accent else 1.0)

    def label(x, y, text, accent=False):
        ax.text(x, y, text, ha="center", va="center", fontsize=10,
                color="white" if accent else INK, fontweight="bold" if accent else "normal")

    def terminator(x, y, text, w=3.0):
        ax.add_patch(FancyBboxPatch((x - w / 2, y - ph / 2), w, ph,
                                    boxstyle=f"round,pad=0,rounding_size={ph / 2}",
                                    **style(False)))
        label(x, y, text)

    def data(x, y, text, w=2.8, skew=0.3):
        pts = [(x - w / 2 + skew, y + ph / 2), (x + w / 2 + skew, y + ph / 2),
               (x + w / 2 - skew, y - ph / 2), (x - w / 2 - skew, y - ph / 2)]
        ax.add_patch(Polygon(pts, closed=True, **style(False)))
        label(x, y, text)

    def process(x, y, text, accent=False, w=pw):
        ax.add_patch(plt.Rectangle((x - w / 2, y - ph / 2), w, ph, **style(accent)))
        label(x, y, text, accent)

    def decision(x, y, text):
        pts = [(x, y + dh), (x + dw, y), (x, y - dh), (x - dw, y)]
        ax.add_patch(Polygon(pts, closed=True, **style(False)))
        label(x, y, text)

    def flow(points, accent=False, head=True):
        c = ACCENT if accent else INK
        lw = 1.6 if accent else 1.0
        for (x1, y1), (x2, y2) in zip(points[:-2], points[1:-1]):
            ax.plot([x1, x2], [y1, y2], color=c, linewidth=lw, solid_capstyle="butt")
        ax.add_patch(FancyArrowPatch(points[-2], points[-1],
                                     arrowstyle="-|>" if head else "-", mutation_scale=12,
                                     color=c, linewidth=lw, shrinkA=0, shrinkB=0))

    def note(x, y, text, accent=False):
        ax.text(x, y, text, fontsize=9.5, ha="center", va="center",
                color=ACCENT if accent else INK, fontweight="bold" if accent else "normal")

    cx, lx, rx, fx = 5.2, 1.75, 7.8, 10.9
    y_start, y_in, y_cls, y_dec = 10.4, 9.1, 7.8, 6.3
    y_a, y_b, y_num, y_end = 4.85, 3.5, 1.95, 0.55

    terminator(cx, y_start, "Start")
    data(cx, y_in, "Guest message\n(text or speech)")
    process(cx, y_cls, "Intent model +\nkeyword check")
    decision(cx, y_dec, "Safety or\nunknown?")
    process(lx, y_a, "Block: show warning\ncard + holding reply", accent=True, w=3.2)
    process(lx, y_b, "Host answers in\nown words", accent=True, w=3.2)
    process(rx, y_a, "Draft reply from\nfarm profile only")
    process(rx, y_b, "Translate draft into\nguest's language")
    decision(rx, y_num, "Numbers\nmatch?")
    process(fx, y_num, "Use English\ndraft; tell host", w=2.0)
    terminator(cx, y_end, "Host approves\nand sends")

    flow([(cx, y_start - ph / 2), (cx, y_in + ph / 2)])
    flow([(cx, y_in - ph / 2), (cx, y_cls + ph / 2)])
    flow([(cx, y_cls - ph / 2), (cx, y_dec + dh)])
    # Yes: blocked path (accent).
    flow([(cx - dw, y_dec), (lx, y_dec), (lx, y_a + ph / 2)], accent=True)
    note((cx - dw + lx) / 2 + 0.2, y_dec + 0.25, "Yes", accent=True)
    flow([(lx, y_a - ph / 2), (lx, y_b + ph / 2)], accent=True)
    flow([(lx, y_b - ph / 2), (lx, y_end), (cx - 1.5, y_end)], accent=True)
    # No: drafted path.
    flow([(cx + dw, y_dec), (rx, y_dec), (rx, y_a + ph / 2)])
    note((cx + dw + rx) / 2 - 0.2, y_dec + 0.25, "No")
    flow([(rx, y_a - ph / 2), (rx, y_b + ph / 2)])
    flow([(rx, y_b - ph / 2), (rx, y_num + dh)])
    flow([(rx + dw, y_num), (fx - 1.0, y_num)])
    note(rx + dw + 0.35, y_num + 0.28, "No")
    flow([(rx, y_num - dh), (rx, y_end), (cx + 1.5, y_end)])
    note(rx + 0.3, y_num - dh - 0.25, "Yes")
    flow([(fx, y_num - ph / 2), (fx, y_end), (rx, y_end)], head=False)
    save(fig, "fig1.png")


# Figure 2: offline coverage. Source: turaista-dataset-audit.ipynb,
# cells 74048176 (MMS), 6f8b755f (FLORES+, NLLB), 6b4b1f29 (FLEURS);
# Tagalog FLORES+ found by prefix lookup in turaista-model-eval.ipynb cell 4d4ecb7a.
def fig2():
    langs = ["Tagalog", "Cebuano", "Ilocano", "English", "Korean", "Japanese", "Chinese"]
    cols = ["MMS speech\nrecognition", "MMS speech\noutput", "NLLB-200\ntranslation",
            "FLORES+\ntext test", "FLEURS\nspeech test"]
    have = {
        "Tagalog": [1, 1, 1, 1, 1],
        "Cebuano": [1, 1, 1, 1, 1],
        "Ilocano": [1, 1, 1, 1, 0],
        "English": [1, 1, 1, 1, 1],
        "Korean": [1, 1, 1, 1, 1],
        "Japanese": [1, 0, 1, 1, 1],
        "Chinese": [1, 0, 1, 1, 1],
    }
    fig, ax = plt.subplots(figsize=(6.2, 3.6))
    for i, lang in enumerate(langs):
        for j, v in enumerate(have[lang]):
            y = len(langs) - 1 - i
            if v:
                ax.add_patch(plt.Rectangle((j + 0.12, y + 0.12), 0.76, 0.76,
                                           facecolor=GREY, edgecolor=GREY))
            else:
                ax.add_patch(plt.Rectangle((j + 0.12, y + 0.12), 0.76, 0.76,
                                           facecolor="white", edgecolor=ACCENT, linewidth=1.6))
                ax.text(j + 0.5, y + 0.5, "missing", ha="center", va="center",
                        fontsize=7.5, color=ACCENT, fontweight="bold")
    ax.set_xlim(0, len(cols))
    ax.set_ylim(0, len(langs))
    ax.set_xticks([j + 0.5 for j in range(len(cols))], cols, fontsize=8)
    ax.set_yticks([len(langs) - 1 - i + 0.5 for i in range(len(langs))], langs)
    ax.xaxis.tick_top()
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_title("Every language has offline models; three gaps remain in speech", loc="left",
                 pad=34)
    ax.text(0, -0.45, "Grey = available. Host languages: Tagalog, Cebuano, Ilocano.",
            fontsize=7.5, color=QUIET, transform=ax.transData)
    save(fig, "fig2.png")


# Figure 3: chrF++ of NLLB-200 600M on 100 FLORES+ devtest sentences.
# Source: turaista-model-eval.ipynb, cell 79bdc21e (summary printout).
def fig3():
    src = ["English", "Korean", "Japanese", "Chinese"]
    tgt = ["Tagalog", "Cebuano", "Ilocano"]
    chrf = [
        [57.5, 55.8, 52.4],  # en->tl, en->ceb, en->ilo
        [42.7, 41.3, 40.1],  # ko->tl, ko->ceb, ko->ilo
        [42.3, 42.0, 39.4],  # ja->tl, ja->ceb, ja->ilo
        [42.8, 43.8, 40.8],  # zh->tl, zh->ceb, zh->ilo
    ]
    fig, ax = plt.subplots(figsize=(4.8, 3.2))
    im = ax.imshow(chrf, cmap="Blues", vmin=30, vmax=60, aspect="auto")
    for i in range(len(src)):
        for j in range(len(tgt)):
            v = chrf[i][j]
            ax.text(j, i, f"{v:.1f}", ha="center", va="center", fontsize=10,
                    color="white" if v > 50 else INK, fontweight="bold")
    ax.set_xticks(range(len(tgt)), tgt)
    ax.set_yticks(range(len(src)), src)
    ax.set_xlabel("Target (host) language")
    ax.set_ylabel("Source (guest) language")
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    cb = fig.colorbar(im, ax=ax, fraction=0.05, pad=0.03)
    cb.set_label("chrF++ (higher is better)")
    ax.set_title("English translates best into host languages", loc="left")
    save(fig, "fig4.png")


# Figure 4: MMS-1B-all WER on 100 FLEURS test utterances per language.
# Source: turaista-model-eval.ipynb, cells 8bd52046 and 79bdc21e.
def fig4():
    langs = ["Tagalog", "Cebuano"]
    wer = [13.1, 14.4]
    fig, ax = plt.subplots(figsize=(3.6, 2.8))
    bars = ax.bar(langs, wer, color=GREY, width=0.55)
    for b, v in zip(bars, wer):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.4, f"{v:.1f}%", ha="center",
                fontsize=9, fontweight="bold", color=INK)
    ax.set_ylim(0, 20)
    ax.set_yticks([0, 5, 10, 15, 20])
    ax.set_ylabel("Word error rate (%)")
    ax.set_title("About 1 word in 7 is wrong", loc="left")
    ax.text(0.5, -0.2, "n = 100 FLEURS test utterances per language", ha="center",
            fontsize=7.5, color=QUIET, transform=ax.transAxes)
    save(fig, "fig3.png")


# Figure 5: intent model on the template test (n = 250).
# Source: turaista-intent.ipynb, cell 18 (report printout).
def fig5():
    metrics = ["Accuracy\n(all intents)", "Safety recall\n(DIETARY_SAFETY, n = 49)"]
    model_only = [96.0, 87.8]   # accuracy 96.0%; recall 0.878
    with_rule = [98.4, 100.0]   # accuracy 98.4%; recall 1.0
    x = range(len(metrics))
    width = 0.36
    fig, ax = plt.subplots(figsize=(4.8, 3.0))
    b1 = ax.bar([i - width / 2 for i in x], model_only, width, color=GREY,
                label="Model only")
    b2 = ax.bar([i + width / 2 for i in x], with_rule, width, color=ACCENT,
                label="Model + keyword rule")
    for bars in (b1, b2):
        for b in bars:
            v = b.get_height()
            ax.text(b.get_x() + b.get_width() / 2, v + 1.2, f"{v:.1f}%", ha="center",
                    fontsize=8.5, fontweight="bold", color=INK)
    ax.set_xticks(list(x), metrics)
    ax.set_ylim(0, 112)
    ax.set_yticks([0, 25, 50, 75, 100])
    ax.set_ylabel("Percent of test messages")
    ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.2), ncol=2,
              fontsize=8)
    ax.set_title("The keyword rule catches the safety messages the model misses", loc="left")
    save(fig, "fig5.png")


if __name__ == "__main__":
    for f in (fig1, fig2, fig3, fig4, fig5):
        f()
