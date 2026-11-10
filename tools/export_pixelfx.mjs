#!/usr/bin/env node
// Exporte les effets pixelfx choisis dans data/pixelfx.json en planches pour Godot (assets/pixelfx/).
//
//   node tools/export_pixelfx.mjs [--data=data/pixelfx_xxx.json] [chemin_de_pixelfx]   (défaut : data/pixelfx.json,
//   D:/dev/creos-plateau/pixelfx). Toute entrée qui a une clé "fx" (à n'importe quelle profondeur) est exportée.
//
// Une planche par couple (effet, palette) : <categorie>-<nom>[-<palette>].png (grille, 4096 px de large au plus,
// recadrée sur ce qui est dessiné) + .json { frames, size, columns, fps, pivot, loop }. Le pivot est l'origine de
// l'effet (les pieds pour un effet de personnage, le point d'impact sinon).

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const ARGS = process.argv.slice(2);
const DATA = (ARGS.find((a) => a.startsWith("--data=")) ?? "--data=data/pixelfx.json").slice(7);
const PFX = ARGS.find((a) => !a.startsWith("--")) ?? "D:/dev/creos-plateau/pixelfx";
const lib = await import(pathToFileURL(join(PFX, "tools/lib/fxlib.mjs")).href);
const { encodePNG } = await import(pathToFileURL(join(PFX, "tools/lib/png.mjs")).href);
const cfg = JSON.parse(readFileSync(join(ROOT, DATA), "utf8"));
const base = JSON.parse(readFileSync(join(ROOT, "data/pixelfx.json"), "utf8"));
cfg.palettes = { ...base.palettes, ...(cfg.palettes ?? {}) };
// toutes les entrées { fx, ... } du fichier, où qu'elles soient
const entries = [];
(function walk(o, path) {
  if (o && typeof o === "object") {
    if (typeof o.fx === "string") entries.push([path, o]);
    for (const [k, v] of Object.entries(o)) if (k !== "fx") walk(v, path ? path + "." + k : k);
  }
})(cfg, "");
const OUT = join(ROOT, "assets/pixelfx");
mkdirSync(OUT, { recursive: true });

const FPS = 24;
const done = new Set();
for (const [attack, e] of entries) {
  const key = e.fx.replace("/", "-") + (e.pal ? "-" + e.pal : "");
  if (done.has(key)) continue;
  done.add(key);
  const fx = await lib.loadEffect(e.fx, join(PFX, "src/fx"));
  const options = { ...(e.pal ? { palette: cfg.palettes[e.pal] } : {}), ...(e.opts ?? {}) };  // opts : options de l'effet pixelfx
  const r = lib.renderFrames(fx, { fps: FPS, bg: "none", actor: false, seed: 7, options });
  // recadrage sur la zone dessinée de toutes les images
  let x0 = r.w, y0 = r.h, x1 = -1, y1 = -1;
  for (const f of r.frames) for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) {
    if (f.clear[(y * r.w + x) * 4 + 3] > 8) { if (x < x0) x0 = x; if (y < y0) y0 = y; if (x > x1) x1 = x; if (y > y1) y1 = y; }
  }
  if (x1 < 0) { console.log(`${attack}: ${e.fx} vide, ignoré`); continue; }
  // on ne garde que ce qui sera joué (durée max × vitesse)
  if (e.max) r.frames.length = Math.min(r.frames.length, Math.ceil(e.max * (e.speed ?? 1) * FPS) + 1);
  const w = x1 - x0 + 1, h = y1 - y0 + 1, n = r.frames.length;
  const cols = Math.max(1, Math.min(n, Math.floor(4096 / w))), rows = Math.ceil(n / cols);
  const W = cols * w, H = rows * h, data = new Uint8ClampedArray(W * H * 4);
  r.frames.forEach((f, i) => {
    const ox = (i % cols) * w, oy = Math.floor(i / cols) * h;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const s = ((y + y0) * r.w + x + x0) * 4, d = ((oy + y) * W + ox + x) * 4;
      for (let c = 0; c < 4; c++) data[d + c] = f.clear[s + c];
    }
  });
  writeFileSync(join(OUT, key + ".png"), encodePNG(W, H, data));
  const [ox, oy] = fx.meta.origin;
  writeFileSync(join(OUT, key + ".json"), JSON.stringify({ fx: e.fx, frames: n, size: [w, h], columns: cols, fps: FPS, pivot: [ox - x0, oy - y0], loop: !!fx.meta.loop }));
  console.log(`${key}: ${n} images ${w}x${h}`);
}
