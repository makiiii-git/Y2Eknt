"""端末のスクリーンショットにキャプションと端末フレームを付けて 1080x1920 の
Playストア用画像にする。

使い方:
  1. デバッグ版（applicationIdSuffix .debug）をテスト機に入れ、共有インテントで
     サンプル経路を投入して各画面を `adb exec-out screencap -p` で撮る（1080x2400）
  2. python3 store-assets/compose_screenshots.py <撮影ディレクトリ> store-assets/screenshots

必要: Pillow、macOS のヒラギノ角ゴシック。他社サイト・他社アプリの画面は撮影しない。
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC = sys.argv[1]          # 撮影した生スクショのディレクトリ
OUT = sys.argv[2]          # 出力ディレクトリ
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1920
GREEN = (0, 160, 68)
GREEN_DARK = (0, 110, 48)
WHITE = (255, 255, 255)
FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc"
FONT_R = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"

# (ファイル名, 見出し, サブ見出し)
SHOTS = [
    ("01-result.png",   "共有するだけで\n予約検索の条件を自動入力", "駅名・日付・時刻の打ち直しはもう不要"),
    ("02-home.png",     "乗換アプリの「共有」から\nそのまま受け取る", "コピー＆ペーストなし。3ステップで予約サイトへ"),
    ("03-jrsegment.png","地下鉄・私鉄の区間は\n自動で除外", "新幹線・特急に乗る駅だけを予約サイトへ渡します"),
    ("04-ex.png",       "東海道・山陽・九州新幹線は\nEX予約にも対応", "経路に合わせて予約サイトを自動で振り分け（プレミアム）"),
    ("05-history.png",  "検索履歴から\n同じ条件で開き直せる", "よく使う区間はワンタップで再検索"),
    ("06-settings.png", "共有したら即、予約サイトへ", "「自動で開く」でボタン操作も省略（プレミアム）"),
]

def vgradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h), top)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img

def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return m

def draw_centered(draw, y, text, font, fill, line_gap=14):
    for line in text.split("\n"):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        draw.text(((W - tw) / 2 - bbox[0], y - bbox[1]), line, font=font, fill=fill)
        y += th + line_gap
    return y

font_h = ImageFont.truetype(FONT_B, 64)
font_s = ImageFont.truetype(FONT_R, 36)

for i, (fname, head, sub) in enumerate(SHOTS, start=1):
    src_path = os.path.join(SRC, fname)
    if not os.path.exists(src_path):
        print("skip (missing)", fname); continue
    shot = Image.open(src_path).convert("RGB")
    sw, sh = shot.size
    # 設定画面はGitHub版限定の項目（更新確認・ソースコード）を背景色で塗りつぶす
    if fname == "06-settings.png":
        bg = shot.getpixel((sw // 2, sh - 60))
        ImageDraw.Draw(shot).rectangle([0, 1556, sw, sh], fill=bg)
    # ステータスバー（通知アイコン入り）を切り落とし、下部の空白も詰める
    STATUS_H = 125
    target_h = min(sh, STATUS_H + int(sw * 1.88))
    shot = shot.crop((0, STATUS_H, sw, target_h))

    canvas = vgradient(W, H, GREEN, GREEN_DARK)
    draw = ImageDraw.Draw(canvas)
    y = 110
    y = draw_centered(draw, y, head, font_h, WHITE)
    y += 10
    y = draw_centered(draw, y, sub, font_s, (225, 245, 232))

    # 端末フレーム（角丸・影）。残り高さに合わせて縮小
    top = y + 60
    frame_pad = 18
    avail_h = H - top + 140          # 下は少しはみ出させて奥行きを出す
    scale = (avail_h - 2 * frame_pad) / shot.height
    inner_w = int(shot.width * scale)
    inner_h = int(shot.height * scale)
    if inner_w > W - 120:
        scale = (W - 120) / shot.width
        inner_w = int(shot.width * scale); inner_h = int(shot.height * scale)
    inner = shot.resize((inner_w, inner_h), Image.LANCZOS)
    fw, fh = inner_w + 2 * frame_pad, inner_h + 2 * frame_pad
    fx = (W - fw) // 2
    fy = top

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([fx + 10, fy + 24, fx + fw + 10, fy + fh + 24], 70, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)

    frame = Image.new("RGBA", (fw, fh), (20, 20, 20, 255))
    frame.putalpha(rounded_mask((fw, fh), 70))
    inner_rgba = inner.convert("RGBA")
    inner_rgba.putalpha(rounded_mask((inner_w, inner_h), 54))
    frame.alpha_composite(inner_rgba, (frame_pad, frame_pad))
    canvas.alpha_composite(frame, (fx, fy))

    out = canvas.convert("RGB")
    out.save(os.path.join(OUT, f"{i:02d}.png"), optimize=True)
    print("wrote", f"{i:02d}.png", out.size)
