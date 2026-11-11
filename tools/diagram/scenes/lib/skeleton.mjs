// Node-side helpers that produce Excalidraw *element skeletons* (plain JSON).
// The skeleton is turned into real elements inside the browser by
// convertToExcalidrawElements(), which measures text and wires up bindings.
//
// This file is imported by the scene module and runs in Node.js. It is not
// part of the browser bundle, so changing it needs no re-bundle.
//
// Conventions used by every helper:
//   - Every element gets a stable, readable id so the saved scene diffs cleanly.
//   - Text never gets a width or height; Excalidraw measures it.
//   - Text inside a box is free-standing text with a fitIn hint, never a label
//     bound to the box: Excalidraw grows a box to fit its bound label without
//     saying so, and everything placed from the size the scene asked for would
//     then be off. Only an arrow can carry a bound label (see arrow()).
//   - Centred and right-aligned text is positioned by its centre or right
//     edge: Excalidraw resolves `x` that way when textAlign is set.
//   - Node.js cannot measure text, so anything else that depends on a text's
//     width is expressed as a `layout` hint that src/browser-entry.js resolves
//     after measuring (see applyLayoutHints there):
//       { fitIn: id, margin }   fail the build if the text leaves that box
//       { endsBefore: x }       fail the build if the text runs past x
//       { leftOf: id, gap }     put this element just left of another one
//       { centerIn: id }        centre this element in another one
//   - Shape helpers return { id, x, y, width, height, elements }. The geometry
//     is what arrows attach to; `elements` is what goes into the scene.

const NUNITO = 6; // FONT_FAMILY.Nunito in @excalidraw/excalidraw 0.18
const LINE_HEIGHT = 1.35; // Excalidraw's line height for Nunito

const INK = "#232F3E";
const WHITE = "#FFFFFF";

// Service box colours by AWS category: stroke is the category colour, fill a
// pale tint of it that keeps dark text readable.
const CATEGORY = Object.freeze({
  compute: { stroke: "#ED7100", fill: "#FDF0E3" },
  database: { stroke: "#C925D1", fill: "#F9E9FA" },
  networking: { stroke: "#8C4FFF", fill: "#F1EAFF" },
  analytics: { stroke: "#8C4FFF", fill: "#F1EAFF" },
  security: { stroke: "#DD344C", fill: "#FBEAEC" },
  management: { stroke: "#E7157B", fill: "#FCE7F1" },
  storage: { stroke: "#7AA116", fill: "#F2F6E8" },
  general: { stroke: "#232F3E", fill: "#F2F3F3" },
});

// Group (container) borders. `title` is the colour of the group's title: a
// darker shade of the border hue, because the border colours themselves are
// too light for text (below 3.6:1 on their own tint). Every title colour has
// a contrast of at least 5:1 on the group's fill. Subtitles are set in ink.
const GROUP = Object.freeze({
  cloud: { stroke: "#242F3E", title: INK, fill: WHITE, strokeStyle: "solid" },
  region: { stroke: "#00A4A6", title: "#006F71", fill: "transparent", strokeStyle: "dotted" },
  vpc: { stroke: "#8C4FFF", title: "#6B2FD9", fill: "#FBF9FF", strokeStyle: "solid" },
  publicSubnet: { stroke: "#7AA116", title: "#4B6B0A", fill: "#F2F6E8", strokeStyle: "solid" },
  appSubnet: { stroke: "#00A4A6", title: "#006F71", fill: "#E6F6F7", strokeStyle: "solid" },
  dataSubnet: { stroke: "#3F51D9", title: "#3443B8", fill: "#EBEEFC", strokeStyle: "solid" },
  nodeGroup: { stroke: "#ED7100", title: "#A84F00", fill: "#FFFAF4", strokeStyle: "dashed" },
  generic: { stroke: "#7D8998", title: "#5F6B7A", fill: "transparent", strokeStyle: "dashed" },
});

// Arrow classes. Each differs from the others in stroke style or weight as
// well as colour, so the diagram still reads in greyscale.
// `color` draws the line and the number badge. `text`, where given, is a
// darker shade of it for the label: the line colours are a little too light
// for small text (4.1:1 to 4.3:1 on the tints the labels sit on), the text
// shades have a contrast of at least 4.9:1 there.
const TRAFFIC_ORANGE = "#D9480F";
const TRAFFIC_ORANGE_TEXT = "#C2410C";
const INTERNAL_BLUE = "#0972D3";
const INTERNAL_BLUE_TEXT = "#075FB0";
const THIN = 1.5; // clearly lighter than the 2-unit classes, still visible when the picture is scaled down
const FLOW = Object.freeze({
  public: { color: TRAFFIC_ORANGE, text: TRAFFIC_ORANGE_TEXT, strokeWidth: 4, strokeStyle: "solid", endArrowhead: "triangle" },
  egress: { color: TRAFFIC_ORANGE, text: TRAFFIC_ORANGE_TEXT, strokeWidth: 2, strokeStyle: "dashed", endArrowhead: "triangle" },
  internal: { color: INTERNAL_BLUE, text: INTERNAL_BLUE_TEXT, strokeWidth: 2, strokeStyle: "solid", endArrowhead: "triangle" },
  control: { color: INTERNAL_BLUE, text: INTERNAL_BLUE_TEXT, strokeWidth: THIN, strokeStyle: "solid", endArrowhead: "triangle", startArrowhead: "triangle" },
  api: { color: "#5F6B7A", strokeWidth: 2, strokeStyle: "dotted", endArrowhead: "triangle" },
  association: { color: INK, strokeWidth: THIN, strokeStyle: "solid", endArrowhead: null },
});

export const SIZE = Object.freeze({
  containerTitle: 20,
  groupTitle: 18,
  boxTitle: 19,
  boxLine: 15,
  boxLineDense: 14, // for boxes whose title would otherwise reach the tag on their top edge
  chip: 15,
  small: 14, // the minimum: subtitles, tags, digits in number badges
  arrowLabel: 15,
  legend: 15,
});

// One corner radius for every rounded box. Excalidraw's own default follows
// the height of the box (a quarter of the shorter side, up to 32), which gives
// neighbours of different heights visibly different corners. A box lower than
// four times this radius still gets a quarter of its height: 11 on a
// one-line box, 6 on chips and tags.
const CORNER_RADIUS = 12;
const ADAPTIVE_RADIUS = 3; // ROUNDNESS.ADAPTIVE_RADIUS in @excalidraw/excalidraw 0.18

const TITLE_TOP = 6; // container border to the top of its title
// Height of a tag, and its distance from the corner of the edge it sits on:
// on a service box the tag ends where the corner arc begins.
const TAG = { h: 24, inset: CORNER_RADIUS };
const BADGE = 24; // diameter of the numbered circle in front of an arrow label
const BADGE_GAP = 5;
const LABEL_CLEAR = 10; // between a vertical line and the label (or number badge) beside it
const LABEL_LIFT = 7; // between a horizontal line and the text box above it; the glyphs sit about 5 higher

/** Crisp "architect" strokes instead of Excalidraw's sketchy default. */
const base = { roughness: 0, fillStyle: "solid", strokeWidth: 2, opacity: 100, angle: 0 };

const lineHeight = (fontSize) => fontSize * LINE_HEIGHT;

function rect({ id, x, y, w, h, stroke, fill, strokeStyle = "solid", strokeWidth = 2, rounded = false, groupIds }) {
  return {
    type: "rectangle",
    id,
    x,
    y,
    width: w,
    height: h,
    ...base,
    strokeWidth,
    strokeColor: stroke,
    backgroundColor: fill,
    strokeStyle,
    roundness: rounded ? { type: ADAPTIVE_RADIUS, value: CORNER_RADIUS } : null,
    ...(groupIds ? { groupIds } : {}),
  };
}

/**
 * Free-standing text. `anchor` says what `x` means: "start", "middle" or
 * "end". `fitIn` (with `margin`) and `endsBefore` are checked by the build.
 */
export function text({ id, x, y, text: value, fontSize = SIZE.small, color = INK, anchor = "start", fitIn, margin, endsBefore, groupIds }) {
  const layout = {
    ...(fitIn ? { fitIn, margin: margin ?? 4 } : {}),
    ...(endsBefore === undefined ? {} : { endsBefore }),
  };
  return {
    type: "text",
    id,
    x,
    y,
    text: value,
    fontSize,
    fontFamily: NUNITO,
    textAlign: { start: "left", middle: "center", end: "right" }[anchor],
    strokeColor: color,
    roughness: 0,
    ...(groupIds ? { groupIds } : {}),
    ...(Object.keys(layout).length ? { layout } : {}),
  };
}

const shape = (frame, elements) => ({
  id: frame.id,
  x: frame.x,
  y: frame.y,
  width: frame.width,
  height: frame.height,
  elements,
});

/**
 * Group container (cloud, VPC, subnet tier, logical group). The title sits in
 * the top-left corner, or top-right with titleAlign "end", with an optional
 * smaller second line under it.
 */
export function container({ id, x, y, w, h, title, subtitle, kind = "generic", fontSize = SIZE.groupTitle, titleAlign = "start", inset = 12 }) {
  const g = GROUP[kind];
  const groupIds = [`${id}__group`];
  const frame = rect({ id, x, y, w, h, stroke: g.stroke, fill: g.fill, strokeStyle: g.strokeStyle, groupIds });
  const tx = titleAlign === "end" ? x + w - inset : x + inset;
  const elements = [
    frame,
    text({ id: `${id}__title`, x: tx, y: y + TITLE_TOP, text: title, fontSize, color: g.title, anchor: titleAlign, fitIn: id, margin: 2, groupIds }),
  ];
  if (subtitle) {
    elements.push(
      text({ id: `${id}__subtitle`, x: tx, y: y + TITLE_TOP + lineHeight(fontSize), text: subtitle, fontSize: SIZE.small, anchor: titleAlign, fitIn: id, margin: 2, groupIds }),
    );
  }
  return shape(frame, elements);
}

/**
 * Width of a tag. Node.js cannot measure the label, so this is an estimate:
 * 6.7 is the average glyph width of these labels at SIZE.small, 18 the
 * padding. The fitIn hint on the tag's text fails the build if a label turns
 * out wider than that.
 */
const tagWidth = (label) => Math.ceil(label.length * 6.7 + 18);

/**
 * Small tag centred on a horizontal edge, used for "SG: name". `x` is its left
 * edge, or its right edge with align "end". Returns elements only; a tag has
 * no geometry of its own.
 */
function tagElements({ ownerId, x, align = "start", edgeY, label, groupIds }) {
  const id = `${ownerId}__tag`;
  const w = tagWidth(label);
  const h = TAG.h;
  const left = align === "end" ? x - w : x;
  const y = edgeY - h / 2;
  const stroke = CATEGORY.security.stroke;
  return [
    rect({ id, x: left, y, w, h, stroke, fill: WHITE, strokeWidth: 1, rounded: true, groupIds }),
    text({ id: `${id}__text`, x: left + w / 2, y: y + (h - lineHeight(SIZE.small)) / 2, text: label, fontSize: SIZE.small, color: stroke, anchor: "middle", fitIn: id, margin: 6, groupIds }),
  ];
}

/** Adds an "SG: name" tag to the top edge of a container, at its left or right end. */
export function withTag(owner, label, { align = "end" } = {}) {
  const x = align === "end" ? owner.x + owner.width - TAG.inset : owner.x + TAG.inset;
  owner.elements.push(...tagElements({ ownerId: owner.id, x, align, edgeY: owner.y, label, groupIds: [`${owner.id}__group`] }));
  return owner;
}

/**
 * A service box coloured by AWS category: a title and optional smaller lines,
 * centred, plus an optional security-group tag on the top edge.
 */
export function node({ id, x, y, w, h, title, lines = [], category = "general", tag, lineSize = SIZE.boxLine }) {
  const c = CATEGORY[category];
  const groupIds = [`${id}__group`];
  const frame = rect({ id, x, y, w, h, stroke: c.stroke, fill: c.fill, rounded: true, groupIds });
  const titleLines = title.split("\n").length;
  const gap = lines.length ? 2 : 0;
  const blockHeight = titleLines * lineHeight(SIZE.boxTitle) + gap + lines.length * lineHeight(lineSize);
  const top = y + (h - blockHeight) / 2;
  const cx = x + w / 2;
  const elements = [
    frame,
    text({ id: `${id}__title`, x: cx, y: top, text: title, fontSize: SIZE.boxTitle, anchor: "middle", fitIn: id, margin: 8, groupIds }),
  ];
  if (lines.length) {
    elements.push(
      text({ id: `${id}__lines`, x: cx, y: top + titleLines * lineHeight(SIZE.boxTitle) + gap, text: lines.join("\n"), fontSize: lineSize, anchor: "middle", fitIn: id, margin: 8, groupIds }),
    );
  }
  if (tag) {
    elements.push(...tagElements({ ownerId: id, x: x + w - TAG.inset, align: "end", edgeY: y, label: tag, groupIds }));
  }
  return shape(frame, elements);
}

/** Small pill with one line of text, used for the per-AZ subnet chips. */
export function chip({ id, x, y, w, h = 24, label, kind }) {
  const g = GROUP[kind];
  const groupIds = [`${id}__group`];
  const frame = rect({ id, x, y, w, h, stroke: g.stroke, fill: WHITE, strokeWidth: 1, rounded: true, groupIds });
  return shape(frame, [
    frame,
    text({ id: `${id}__text`, x: x + w / 2, y: y + (h - lineHeight(SIZE.chip)) / 2, text: label, fontSize: SIZE.chip, anchor: "middle", fitIn: id, margin: 6, groupIds }),
  ]);
}

// ------------------------------------------------------------------ arrows

const OUTWARD = { left: [-1, 0], right: [1, 0], top: [0, -1], bottom: [0, 1] };
const isHorizontal = (side) => side === "left" || side === "right";

/** Point on a side of a rectangle. `at` is an absolute x (top/bottom) or y (left/right). */
function sidePoint(r, side, at) {
  if (!(side in OUTWARD)) {
    throw new Error(`unknown side ${side} on ${r.id}`);
  }
  const [lo, length] = isHorizontal(side) ? [r.y, r.height] : [r.x, r.width];
  const v = at ?? lo + length / 2;
  // Positions are derived from layout constants; catch an edit that slides an
  // arrow off the box it is supposed to touch.
  if (v < lo + 4 || v > lo + length - 4) {
    throw new Error(`${v} is not on the ${side} side of ${r.id} (${lo} to ${lo + length})`);
  }
  switch (side) {
    case "left":
      return [r.x, v];
    case "right":
      return [r.x + r.width, v];
    case "top":
      return [v, r.y];
    default:
      return [v, r.y + r.height];
  }
}

/**
 * Where a label belongs on a polyline: on segment `segment` (default: the
 * longest), at absolute coordinate `at` along it (default: its midpoint).
 * With `endsAllowed` the label may be level with an end of the segment.
 */
function labelAnchor(points, segment = "longest", at, endsAllowed = false) {
  const len = (i) => Math.hypot(points[i + 1][0] - points[i][0], points[i + 1][1] - points[i][1]);
  let k = segment;
  if (segment === "longest") {
    k = 0;
    for (let i = 1; i < points.length - 1; i++) {
      if (len(i) > len(k)) {
        k = i;
      }
    }
  }
  const [a, b] = [points[k], points[k + 1]];
  const vertical = a[0] === b[0];
  let t = 0.5;
  if (at !== undefined) {
    const axis = vertical ? 1 : 0;
    t = (at - a[axis]) / (b[axis] - a[axis]);
    if (!(endsAllowed ? t >= 0 && t <= 1 : t > 0 && t < 1)) {
      throw new Error(`label position ${at} is not on segment ${k}`);
    }
  }
  return { segment: k, vertical, point: [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t] };
}

/**
 * Excalidraw puts an arrow's bound label on the path's "middle": the middle
 * POINT when the point count is odd, else the midpoint of the middle segment.
 * This inserts the anchor plus enough collinear points (invisible on a sharp
 * polyline) to make the anchor that middle point.
 */
function withMiddlePoint(points, { segment: k, point: mid }) {
  const lerp = (p, q, t) => [p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t];
  const before = points.slice(0, k + 1);
  const after = points.slice(k + 1);
  const need = Math.abs(before.length - after.length);
  const pads = Array.from({ length: need }, (_, i) => (i + 1) / (need + 1));
  const padBefore = before.length < after.length ? pads.map((p) => lerp(points[k], mid, p)) : [];
  const padAfter = after.length < before.length ? pads.map((p) => lerp(mid, points[k + 1], p)) : [];
  return [...before, ...padBefore, mid, ...padAfter, ...after];
}

/**
 * Where a free-standing label goes relative to its anchor point on the line.
 * `lead` is the room a number badge takes in front of the text.
 */
function besideLine(id, side, { vertical, point: [px, py] }, lead) {
  const textHeight = lineHeight(SIZE.arrowLabel);
  if (side === "above") {
    if (vertical) {
      throw new Error(`arrow ${id}: a label above the line needs a horizontal segment`);
    }
    return { x: px + lead, y: py - LABEL_LIFT - textHeight, anchor: "start" };
  }
  if (!vertical) {
    throw new Error(`arrow ${id}: a label beside the line needs a vertical segment`);
  }
  return side === "right"
    ? { x: px + LABEL_CLEAR + lead, y: py - textHeight / 2, anchor: "start" }
    : { x: px - LABEL_CLEAR, y: py - textHeight / 2, anchor: "end" };
}

/**
 * Arrow (or plain line) between two shapes.
 *
 * Excalidraw records a binding to each shape but does not move the arrow to
 * the shape edges, so the geometry is computed here.
 *
 *   flow        one of FLOW: sets colour, weight, dash style and arrowheads
 *   from, to    shapes; `to` may also be a bare point { x, y } (no binding)
 *   fromSide, toSide
 *               which side of each shape to attach to (no toSide for a point)
 *   fromAt, toAt
 *               where along that side, as an absolute x or y (default: middle)
 *   route       "straight", or "elbow" for an orthogonal path whose middle
 *               leg can be pinned with `mid` (absolute x or y)
 *   number      drawn as a filled, numbered circle in front of the label,
 *               which has to be free text: see the note on groups below
 *   label       belongs to segment `labelSegment` (default: the longest), at
 *               absolute coordinate `labelAt` along it (default: its middle).
 *               Free text may be level with an end of the segment, which
 *               puts it beside the arrowhead; a label on the line may not.
 *   labelSide   where the label sits relative to that point:
 *               "left", "right"  free text beside a vertical segment, ending
 *                                or starting LABEL_CLEAR away from the line
 *               "above"          free text over a horizontal segment; the
 *                                label (number first) starts at `labelAt`
 *               "on"             bound to the arrow, interrupting the line
 *                                (default). Rejected on a vertical segment:
 *                                Excalidraw wraps a bound label to the width
 *                                of its arrow, and a vertical arrow has none.
 *                                Meant for solid lines: the gap cuts dashes
 *                                and dots in half.
 *   labelEndsBefore
 *               for free text: the build fails if the label runs past this x
 *   gap         distance kept between each end and the shape it attaches to
 *
 * A label and its number badge (a circle and a digit) share a group, so the
 * three elements move together in the editor. The arrow is not in that group:
 * its bindings stay as they are, and the label does not follow a dragged
 * arrow. A label bound to its arrow cannot join a group of its own, which is
 * why a numbered label has to be free text.
 */
export function arrow({
  id,
  flow,
  from,
  to,
  fromSide,
  toSide,
  fromAt,
  toAt,
  route = "straight",
  mid,
  number,
  label,
  labelSegment = "longest",
  labelAt,
  labelSide = "on",
  labelEndsBefore,
  gap = 4,
}) {
  const style = FLOW[flow];
  const toIsPoint = to.width === undefined;

  const [ax0, ay0] = sidePoint(from, fromSide, fromAt);
  const ax = ax0 + OUTWARD[fromSide][0] * gap;
  const ay = ay0 + OUTWARD[fromSide][1] * gap;
  let bx = to.x;
  let by = to.y;
  if (!toIsPoint) {
    const [bx0, by0] = sidePoint(to, toSide, toAt);
    bx = bx0 + OUTWARD[toSide][0] * gap;
    by = by0 + OUTWARD[toSide][1] * gap;
  }

  let abs = [[ax, ay], [bx, by]];
  if (route === "elbow" && ax !== bx && ay !== by) {
    const firstH = isHorizontal(fromSide);
    const lastH = toIsPoint ? !firstH : isHorizontal(toSide);
    if (firstH && lastH) {
      const mx = mid ?? (ax + bx) / 2;
      abs = [[ax, ay], [mx, ay], [mx, by], [bx, by]];
    } else if (!firstH && !lastH) {
      const my = mid ?? (ay + by) / 2;
      abs = [[ax, ay], [ax, my], [bx, my], [bx, by]];
    } else if (firstH) {
      abs = [[ax, ay], [bx, ay], [bx, by]];
    } else {
      abs = [[ax, ay], [ax, by], [bx, by]];
    }
  } else if (route === "straight" && ax !== bx && ay !== by) {
    throw new Error(`arrow ${id} is neither horizontal nor vertical; use route "elbow" or align its ends`);
  }
  if (number !== undefined && (!label || labelSide === "on")) {
    throw new Error(`arrow ${id}: a number needs a free-standing label to sit in front of (labelSide "above", "left" or "right")`);
  }
  const anchor = label ? labelAnchor(abs, labelSegment, labelAt, labelSide !== "on") : null;
  if (label && labelSide === "on") {
    if (anchor.vertical) {
      throw new Error(`arrow ${id}: a label on the line needs a horizontal segment; use labelSide "left" or "right" beside a vertical one`);
    }
    if (abs.length > 2 || labelAt !== undefined) {
      abs = withMiddlePoint(abs, anchor);
    }
  }

  const el = {
    type: "arrow",
    id,
    x: ax,
    y: ay,
    points: abs.map(([px, py]) => [px - ax, py - ay]),
    ...base,
    strokeWidth: style.strokeWidth,
    strokeColor: style.color,
    backgroundColor: "transparent",
    strokeStyle: style.strokeStyle,
    roundness: null,
    startArrowhead: style.startArrowhead ?? null,
    endArrowhead: style.endArrowhead,
    start: { id: from.id },
    ...(toIsPoint ? {} : { end: { id: to.id } }),
  };
  const elements = [el];
  const labelColor = style.text ?? style.color;

  if (label && labelSide === "on") {
    el.label = {
      id: `${id}__label`,
      // Excalidraw erases the line under exactly the label's bounding box, so
      // the stroke would touch the first and last glyph. One space each side
      // gives the label room to breathe.
      text: ` ${label} `,
      fontSize: SIZE.arrowLabel,
      fontFamily: NUNITO,
      strokeColor: labelColor,
      roughness: 0,
    };
  } else if (label) {
    // A label without a number is a single element and needs no group.
    const groupIds = number === undefined ? undefined : [`${id}__label-group`];
    const lead = number === undefined ? 0 : BADGE + BADGE_GAP;
    elements.push(
      text({ id: `${id}__label`, ...besideLine(id, labelSide, anchor, lead), text: label, fontSize: SIZE.arrowLabel, color: labelColor, endsBefore: labelEndsBefore, groupIds }),
    );
    if (number !== undefined) {
      elements.push(...numberBadge({ id: `${id}__number`, number, color: style.color, leftOf: `${id}__label`, gap: BADGE_GAP, groupIds }));
    }
  }
  return { id, elements };
}

/**
 * Filled circle with a number in it. Drawn as shapes instead of the Unicode
 * circled digits because none of the bundled fonts has those glyphs; as text
 * they would come from whichever system font happens to have them.
 * Its position comes from layout hints: it sits left of a label whose width
 * is only known once the browser has measured it. `groupIds` is the group it
 * shares with that label.
 */
function numberBadge({ id, number, color, leftOf, gap, groupIds }) {
  return [
    {
      type: "ellipse",
      id,
      x: 0,
      y: 0,
      width: BADGE,
      height: BADGE,
      ...base,
      strokeWidth: 1,
      strokeColor: color,
      backgroundColor: color,
      strokeStyle: "solid",
      groupIds,
      layout: { leftOf, gap },
    },
    {
      ...text({ id: `${id}__text`, x: 0, y: 0, text: String(number), fontSize: SIZE.small, color: WHITE, anchor: "middle", groupIds }),
      layout: { centerIn: id },
    },
  ];
}

// ------------------------------------------------------------------ legend

const LEGEND_SAMPLE = { w: 72, gap: 12 }; // a line sample (four dashes of the dashed class) and the gap before its label

/** Room a line sample takes in front of its label in a legend row. */
export const LEGEND_SAMPLE_ROOM = LEGEND_SAMPLE.w + LEGEND_SAMPLE.gap;

/**
 * Legend panel, placed by its top-left corner. Rows are laid out in columns
 * and read down each column in turn; the panel's size follows from the
 * columns. Everything shares one group id so it moves as a unit.
 * columns: [{ w, rows }]  `w` is the room for that column's widest row,
 *                         sample included; the build fails if a label runs
 *                         past it
 * rows: { flow, label }   a sample of that arrow class
 *       { tag, label }    a sample tag
 *       { label }         a plain line of text
 * Returns the panel's geometry plus `titleY`, the top of its title line, for
 * text that is set beside the panel and should start level with it.
 */
export function legend({ id = "legend", x, y, title = "Legend", columns }) {
  const groupIds = [`${id}__group`];
  const pad = { x: 16, y: 14 };
  const { w: sampleW, gap: sampleGap } = LEGEND_SAMPLE;
  const tagGap = 8;
  const rowGap = 6;
  const columnGap = 36;
  const fontSize = SIZE.legend;
  const rowH = lineHeight(fontSize);
  const titleH = lineHeight(SIZE.groupTitle) + 8;
  const rowCount = Math.max(...columns.map((column) => column.rows.length));
  const w = 2 * pad.x + columns.reduce((sum, column) => sum + column.w, 0) + (columns.length - 1) * columnGap;
  const h = 2 * pad.y + titleH + rowCount * rowH + (rowCount - 1) * rowGap;

  const frame = rect({ id, x, y, w, h, stroke: GROUP.generic.stroke, fill: WHITE, strokeWidth: 1, rounded: true, groupIds });
  const elements = [frame, text({ id: `${id}__title`, x: x + pad.x, y: y + pad.y, text: title, fontSize: SIZE.groupTitle, groupIds })];

  let left = x + pad.x;
  columns.forEach((column, c) => {
    column.rows.forEach((row, r) => {
      const key = `${c + 1}-${r + 1}`;
      const top = y + pad.y + titleH + r * (rowH + rowGap);
      const midY = top + rowH / 2;
      if (row.flow) {
        const style = FLOW[row.flow];
        elements.push({
          type: "arrow", id: `${id}__sample-${key}`, x: left, y: midY, points: [[0, 0], [sampleW, 0]],
          ...base, strokeWidth: style.strokeWidth, strokeColor: style.color, backgroundColor: "transparent", strokeStyle: style.strokeStyle,
          roundness: null, startArrowhead: style.startArrowhead ?? null, endArrowhead: style.endArrowhead, groupIds,
        });
      } else if (row.tag) {
        elements.push(...tagElements({ ownerId: `${id}__sample-${key}`, x: left, edgeY: midY, label: row.tag, groupIds }));
      }
      const indent = row.flow ? sampleW + sampleGap : row.tag ? tagWidth(row.tag) + tagGap : 0;
      elements.push(text({ id: `${id}__text-${key}`, x: left + indent, y: top, text: row.label, fontSize, endsBefore: left + column.w, groupIds }));
    });
    left += column.w + columnGap;
  });
  return { ...shape(frame, elements), titleY: y + pad.y };
}
