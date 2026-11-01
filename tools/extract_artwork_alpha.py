"""Recover a clean alpha cut-out from campus_artwork.jpg.

The JPG has a grey checkerboard "transparency" placeholder baked into its
pixels (JPEG cannot store alpha).

MEASURED GEOMETRY
-----------------
The checkerboard edges were located directly in the source by detecting
tone-transition columns and rows (a 1 px ringing line marks every cell
edge).  A uniform-grid model fits those edges at 94-95%:

    x step = 33.62488, first edge at x = 31.20
    y step = 33.66600, first edge at y = 33.50

    * Tones: 202 (dark), 247 (light).
    * A cell is DARK when (col + row) is ODD.

Because the grid was rescaled by a non-integer factor, JPEG lays a 1 px
darker ringing line along every cell edge.  Solving the blend equation
against a reference that sits exactly on those edges leaves a visible
staircase of the ringing lines.

SOLUTION
--------
The ringing is a *thin, isolated* structure, so we can target it exactly:

  1. Solve the alpha per pixel using a reference taken from the cell's
     own brightest pixels (measured per cell, so no edge-aligned
     reference is ever used).
  2. The ringing survives as a faint 1 px lattice.  It only ever occurs
     on a cell edge and shows up as a local dip -- darker than BOTH
     neighbours along the edge by a small margin -- so we detect that
     dip on the detected edge positions and drop those pixels.
  3. Isolated faint specks (JPEG noise) are dropped by a 3x3
     neighbourhood test, and a final median filter clears the rest.
"""
from PIL import Image, ImageFilter
import statistics

SRC = "assets/images/campus_artwork.jpg"
DST = "assets/images/campus_artwork.png"

CELL_X = 33.62488
CELL_Y = 33.66600
OFFSET_X = 31.20
OFFSET_Y = 33.50
TONE_DARK = 202
TONE_LIGHT = 247

MIN_ALPHA = 14
ALPHA_GAMMA = 1.6

src = Image.open(SRC).convert("L")
W, H = src.size
src_px = src.load()

data = sorted(src.getdata())
INK = int(statistics.median(data[:max(1, len(data) // 67)]))
print("ink tone: %d" % INK)


# ---------------------------------------------------------------------------
# Step 0: find the REAL cell edges.
# ---------------------------------------------------------------------------
def detect_edges(step_hint, offset_hint, extent, axis):
    trans = [0] * extent
    if axis == 'x':
        for y in range(H):
            line = [src_px[x, y] for x in range(W)]
            for i in range(4, W - 4):
                a = statistics.median(line[i - 4:i])
                b = statistics.median(line[i:i + 4])
                if abs(a - b) > 18 and 185 < line[i] < 260:
                    trans[i] += 1
        scale = H
    else:
        for x in range(W):
            line = [src_px[x, y] for y in range(H)]
            for i in range(4, H - 4):
                a = statistics.median(line[i - 4:i])
                b = statistics.median(line[i:i + 4])
                if abs(a - b) > 18 and 185 < line[i] < 260:
                    trans[i] += 1
        scale = W

    groups = []
    run = []
    for i, s in enumerate(trans):
        if s >= scale * 0.55:
            run.append(i)
        else:
            if run:
                groups.append(run)
                run = []
    if run:
        groups.append(run)

    edges = [max(g, key=lambda i: trans[i]) for g in groups]

    # Fill gaps using the analytic model.
    if len(edges) < 3:
        return []
    k0 = int((0 - offset_hint) // step_hint) - 1
    k1 = int((extent - offset_hint) // step_hint) + 2
    model = {k: offset_hint + k * step_hint for k in range(k0, k1)}
    for e in edges:
        k = round((e - offset_hint) / step_hint)
        if k in model:
            model[k] = e
    filled = []
    for k in range(k0, k1):
        if k in model and 0 <= model[k] < extent:
            filled.append(int(round(model[k])))
    out = []
    for v in filled:
        if not out or v > out[-1]:
            out.append(v)
    return out


print("detecting edges...")
x_edges = detect_edges(CELL_X, OFFSET_X, W, 'x')
y_edges = detect_edges(CELL_Y, OFFSET_Y, H, 'y')
print("x edges: %d   y edges: %d" % (len(x_edges), len(y_edges)))


# ---------------------------------------------------------------------------
# Step 1: cell map + per-cell reference tone measured from the cell itself.
# ---------------------------------------------------------------------------
def build_cell_map(edges, extent):
    ids = [0] * extent
    spans = []
    for c in range(len(edges) + 1):
        lo = edges[c - 1] if c - 1 >= 0 else 0
        hi = edges[c] if c < len(edges) else extent
        spans.append((lo, hi))
    c = 0
    for i in range(extent):
        while c + 1 < len(spans) and i >= spans[c][1]:
            c += 1
        ids[i] = c
    return ids, spans


x_ids, x_spans = build_cell_map(x_edges, W)
y_ids, y_spans = build_cell_map(y_edges, H)
print("cells: %d x %d" % (len(x_spans), len(y_spans)))

ref_tone = {}
for cy, (y0, y1) in enumerate(y_spans):
    if y1 - y0 < 3:
        continue
    for cx, (x0, x1) in enumerate(x_spans):
        if x1 - x0 < 3:
            continue
        samples = []
        for y in range(y0 + 1, y1 - 1):
            for x in range(x0 + 1, x1 - 1):
                samples.append(src_px[x, y])
        if len(samples) < 16:
            continue
        samples.sort()
        n = len(samples)
        ref_tone[(cx, cy)] = int(statistics.median(samples[int(n * 0.85):]))

# ---------------------------------------------------------------------------
# Step 2: solve per-pixel alpha.
# ---------------------------------------------------------------------------
alpha = Image.new("L", (W, H), 0)
ap = alpha.load()

for y in range(H):
    cy = y_ids[y]
    for x in range(W):
        cx = x_ids[x]
        ref = ref_tone.get((cx, cy))
        if ref is None:
            col = int((x - OFFSET_X) // CELL_X)
            row = int((y - OFFSET_Y) // CELL_Y)
            ref = TONE_DARK if (col + row) % 2 == 1 else TONE_LIGHT
        denom = ref - INK
        if denom <= 0:
            continue
        a = (ref - src_px[x, y]) * 255.0 / denom
        if a <= MIN_ALPHA:
            continue
        ap[x, y] = 255 if a > 255 else int(a)

print("solved alpha")

# ---------------------------------------------------------------------------
# Step 3: remove the 1 px cell-edge ringing.
#
# The ringing only ever appears ON a cell edge, so we restrict the
# removal to those pixels.  A ringing pixel is darker than BOTH of its
# neighbours along the edge by a small margin -- that dip is the JPEG
# edge artefact, and the true ink coverage there is essentially zero.
# ---------------------------------------------------------------------------
px = alpha.load()
result = alpha.copy()
rp = result.load()

edge_x = set(x_edges)
edge_y = set(y_edges)

for y in range(H):
    for x in range(W):
        if x in edge_x and 0 < x < W - 1:
            l = src_px[x - 1, y]
            r = src_px[x + 1, y]
        elif y in edge_y and 0 < y < H - 1:
            l = src_px[x, y - 1]
            r = src_px[x, y + 1]
        else:
            continue

        obs = src_px[x, y]
        # Ringing: this pixel is darker than BOTH neighbours by a small
        # margin (1..16 levels) -- the tell-tale JPEG edge dip.
        dl = obs - l
        dr = obs - r
        if 1 <= dl <= 16 and 1 <= dr <= 16:
            rp[x, y] = 0

print("removed edge ringing")

# ---------------------------------------------------------------------------
# Step 3b: drop isolated faint specks that survive (JPEG noise), using a
# 3x3 neighbourhood test.  Genuine pale washes are contiguous, so a
# faint pixel with no faint neighbour is noise.
# ---------------------------------------------------------------------------
px = result.load()
result2 = result.copy()
rp2 = result2.load()
for y in range(1, H - 1):
    for x in range(1, W - 1):
        v = px[x, y]
        if v == 0 or v > 90:
            continue
        n = 0
        for yy in range(y - 1, y + 2):
            for xx in range(x - 1, x + 2):
                if px[xx, yy] > 0:
                    n += 1
        if n <= 2:
            rp2[x, y] = 0
result = result2

# ---------------------------------------------------------------------------
# Step 4: median filter to clear residual JPEG speckle, then gamma.
# ---------------------------------------------------------------------------
result = result.filter(ImageFilter.MedianFilter(3))


def gamma(v):
    if v <= MIN_ALPHA:
        return 0
    norm = (v - MIN_ALPHA) / (255.0 - MIN_ALPHA)
    return max(0, min(255, int((norm ** ALPHA_GAMMA) * 255)))


alpha = result.point(gamma)

grey = Image.new("L", (W, H), INK)
out = Image.merge("RGBA", (grey, grey, grey, alpha))
out.save(DST)
print("saved %s %s" % (DST, out.size))

hist = alpha.histogram()
visible = sum(hist[10:])
print("visible ink: %d / %d (%.1f%%)" % (visible, W * H, visible / (W * H) * 100))
