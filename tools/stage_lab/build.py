# 혼합 입체 무대 실험 페이지 만들기: 저장소의 수로 배경 · SD 그림을 data URI로 박아 한 파일로.
# python3 tools/stage_lab/build.py <출력.html> [--local 경로/three.min.js]   (기본은 cdnjs의 three r128)
import base64
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / "assets/battle_env_waterworks"
SD = ROOT / "assets/sd_combat"
# 바닥 그림(floor_ledge)이 시작하는 줄: 그 위는 벽 · 동굴 · 물길
FLOOR_ROW = 369


def png(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def layer(name: str) -> Image.Image:
    return Image.open(ENV / f"{name}.png").convert("RGBA")


def main() -> None:
    out = Path(sys.argv[1])
    three = "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"
    if "--local" in sys.argv:
        three = sys.argv[sys.argv.index("--local") + 1]
    full = Image.new("RGBA", (1440, 880), (11, 10, 15, 255))
    for n in ["far_cave", "near_arch", "water_base", "torch_fixtures", "floor_ledge"]:
        full.alpha_composite(layer(n))
    wall = Image.new("RGBA", (1440, FLOOR_ROW), (11, 10, 15, 255))
    for n in ["far_cave", "near_arch", "water_base", "torch_fixtures"]:
        wall.alpha_composite(layer(n).crop((0, 0, 1440, FLOOR_ROW)))
    floor = layer("floor_ledge").crop((0, FLOOR_ROW, 1440, 880))
    assets = {
        "full": png(full),
        "wall": png(wall),
        "floor": png(floor),
        "shadow": png(layer("projected_shadow")),
        "warden": png(Image.open(SD / "warden/idle/idle_00.png").convert("RGBA")),
        "scout": png(Image.open(SD / "scout_low/idle/idle_00.png").convert("RGBA")),
    }
    man = {k: json.loads((SD / d / "manifest.json").read_text()) for k, d in [("warden", "warden"), ("scout", "scout_low")]}
    page = (Path(__file__).parent / "page_template.html").read_text()
    page = page.replace("/*ASSETS*/", json.dumps(assets)).replace("/*MANIFEST*/", json.dumps(man)).replace("THREE_SRC", three)
    out.write_text(page)
    print(out, f"{len(page) / 1e6:.1f}MB")


main()
