# 구운 효과를 우리 배우(수호자 · 강아지 원본 64×64) 옆에서 미리 본다: 1배로 합성한 뒤 정수배 확대(미리보기만).
# python3 tools/fx/preview_px.py <시트 폴더> [<시트 폴더> ...] --out <폴더> [--scale 3]
# 결과: <이름>_strip.png(전 장 한 줄) · <이름>.gif · <이름>.mp4. 본체는 그대로 얹고 빛 마스크는 더하기로
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ACTORS = ROOT / "p2/vfx/test_ref"
W, H, FLOOR = 260, 120, 96
GUARD = (80, FLOOR)
PUPPY = (180, FLOOR)
# 역할별 기준점: 베기 = 공격자 발 · 맞는 순간 = 맞는 쪽 발 · 패링 = 막는 쪽 앞 바닥
ANCHOR = {"slash": GUARD, "hit": PUPPY, "parry": (GUARD[0] + 22, FLOOR)}


def stage() -> Image.Image:
    img = Image.new("RGBA", (W, H), (22, 26, 40, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, FLOOR, W, H], fill=(34, 40, 54, 255))
    d.line([0, FLOOR, W, FLOOR], fill=(52, 60, 78, 255))
    for name, (fx, fy), foot in [("guardian", GUARD, (31.5, 52)), ("puppy", PUPPY, (33, 52))]:
        a = Image.open(ACTORS / f"{name}.png").convert("RGBA")
        img.alpha_composite(a, (round(fx - foot[0]), round(fy - foot[1])))
    return img


def frames(folder: Path):
    meta = json.loads(next(folder.glob("*.json")).read_text())
    m = meta["meta"]
    sheet = Image.open(folder / m["image"]).convert("RGBA")
    light = Image.open(folder / m["light"]).convert("RGBA")
    out = []
    for f in meta["frames"]:
        r = f["frame"]
        box = (r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
        out.append((sheet.crop(box), light.crop(box), f["duration"]))
    return m, out


def compose(base: Image.Image, m: dict, col: Image.Image, lig: Image.Image) -> Image.Image:
    ax, ay = ANCHOR.get(m.get("role", "hit"), PUPPY)
    px, py = m["pivot"]
    at = (ax - px, ay - py)
    img = base.copy()
    img.alpha_composite(col, at)
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    glow.paste(lig.convert("RGB"), at, lig.split()[3])
    return Image.fromarray(__import__("numpy").minimum(255, __import__("numpy").asarray(img.convert("RGB"), int) + __import__("numpy").asarray(glow, int)).astype("uint8"))


def main() -> None:
    args = sys.argv[1:]
    out = Path(args[args.index("--out") + 1])
    k = int(args[args.index("--scale") + 1]) if "--scale" in args else 3
    folders = [Path(a) for a in args if not a.startswith("--") and a not in (str(out), str(k))]
    out.mkdir(parents=True, exist_ok=True)
    base = stage()
    for folder in folders:
        m, fs = frames(folder)
        shots = [compose(base, m, c, l) for c, l, _ in fs]
        name = folder.name
        strip = Image.new("RGB", (W * len(shots), H))
        for i, s in enumerate(shots):
            strip.paste(s, (i * W, 0))
        strip.resize((strip.width * 2, strip.height * 2), Image.NEAREST).save(out / f"{name}_strip.png")
        tmp = out / f"_{name}"
        tmp.mkdir(exist_ok=True)
        # 효과 앞뒤로 배우만 보이는 0.4초를 붙여 반복 재생에서도 시작 · 끝이 보이게
        seq = [base.convert("RGB")] * 12 + shots + [base.convert("RGB")] * 12
        for i, s in enumerate(seq):
            s.resize((W * k, H * k), Image.NEAREST).save(tmp / f"{i:03d}.png")
        fps = str(m.get("fps", 30))
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", fps, "-i", str(tmp / "%03d.png"),
                        "-vf", "split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none", "-loop", "0", str(out / f"{name}.gif")], check=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", fps, "-i", str(tmp / "%03d.png"),
                        "-pix_fmt", "yuv420p", "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out / f"{name}.mp4")], check=True)
        for p in tmp.glob("*.png"):
            p.unlink()
        tmp.rmdir()
        print(name, len(shots), "장 →", out)


main()
