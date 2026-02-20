#!/usr/bin/env python3
"""Generate App Store screenshots for Move Now app."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import glob as globmod

SRC = os.path.expanduser("~/Desktop/move-now")
OUT = os.path.join(SRC, "app-store")
os.makedirs(OUT, exist_ok=True)

# Get actual filenames (macOS uses \u202f narrow no-break space before AM/PM)
_files = sorted(globmod.glob(os.path.join(SRC, "Screenshot*.png")))
FILE_1 = _files[0]  # 674x1076 - popover
FILE_2 = _files[1]  # 622x1158 - activity log expanded
FILE_3 = _files[2]  # 720x148 - notification banner
FILE_4 = _files[3]  # 772x172 - notification with actions

# App Store Mac screenshot size (Retina)
WIDTH = 2560
HEIGHT = 1600

# Colors
BG_GRADIENT_TOP = (30, 30, 40)
BG_GRADIENT_BOTTOM = (15, 15, 25)
TEXT_WHITE = (255, 255, 255)
TEXT_GRAY = (180, 180, 190)

# Fonts
FONT_TITLE = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 88)
FONT_SUBTITLE = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 48)

# Layout
TEXT_TOP_Y = 80
TEXT_SUB_Y = 190
IMG_TOP_Y = 310


def make_gradient_bg():
    """Create a dark gradient background."""
    img = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(img)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        r = int(BG_GRADIENT_TOP[0] + (BG_GRADIENT_BOTTOM[0] - BG_GRADIENT_TOP[0]) * ratio)
        g = int(BG_GRADIENT_TOP[1] + (BG_GRADIENT_BOTTOM[1] - BG_GRADIENT_TOP[1]) * ratio)
        b = int(BG_GRADIENT_TOP[2] + (BG_GRADIENT_BOTTOM[2] - BG_GRADIENT_TOP[2]) * ratio)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))
    return img


def add_rounded_corners(img, radius):
    """Add rounded corners to an image."""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, img.size[0], img.size[1]], radius=radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result


def add_shadow(bg, size, position, blur=35, opacity=100):
    """Add a drop shadow behind a screenshot."""
    offset = 12
    shadow = Image.new("RGBA", (size[0] + 80, size[1] + 80), (0, 0, 0, 0))
    shadow_inner = Image.new("RGBA", size, (0, 0, 0, opacity))
    shadow.paste(shadow_inner, (40, 40))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur))

    bg_rgba = bg.convert("RGBA")
    bg_rgba.paste(shadow, (position[0] - 40 + offset, position[1] - 40 + offset), shadow)
    return bg_rgba


def center_text(draw, text, y, font, fill):
    """Draw centered text."""
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    x = (WIDTH - text_width) // 2
    draw.text((x, y), text, font=font, fill=fill)


def compose(bg, src_img, scale, y_pos, corner_radius=24):
    """Scale, add shadow + rounded corners, paste onto bg. Returns new bg."""
    new_w = int(src_img.width * scale)
    new_h = int(src_img.height * scale)
    scaled = src_img.resize((new_w, new_h), Image.LANCZOS)
    rounded = add_rounded_corners(scaled, corner_radius)
    x = (WIDTH - new_w) // 2
    bg = add_shadow(bg, (new_w, new_h), (x, y_pos))
    bg.paste(rounded, (x, y_pos), rounded)
    return bg


def create_screenshot_1():
    """Menu bar popover - 'Set Your Schedule'"""
    bg = make_gradient_bg()
    src = Image.open(FILE_1)

    # Crop: remove everything above the popover panel (y=86) and trim left artifacts
    # The popover panel left edge starts around x=38
    # Crop generously to include just the popover with its rounded corners
    src_cropped = src.crop((38, 86, src.width, src.height))

    # Scale to fill width nicely, allowing bleed off bottom
    # Cropped size: ~636 x 990
    # Target: fit within ~1200px wide centered
    scale = 1200 / src_cropped.width
    bg = compose(bg, src_cropped, scale, IMG_TOP_Y, 20)

    draw = ImageDraw.Draw(bg)
    center_text(draw, "Set Your Schedule", TEXT_TOP_Y, FONT_TITLE, TEXT_WHITE)
    center_text(draw, "Customize reminders to fit your day", TEXT_SUB_Y, FONT_SUBTITLE, TEXT_GRAY)

    bg.convert("RGB").save(os.path.join(OUT, "01_set_your_schedule.png"), "PNG")
    print("Created 01_set_your_schedule.png")


def create_screenshot_2():
    """Activity log - 'Track Your Activity'"""
    bg = make_gradient_bg()
    src = Image.open(FILE_2)

    # This image is 622x1158 and shows the full popover with activity log expanded
    # Scale to a similar width as screenshot 1
    scale = 1200 / src.width
    bg = compose(bg, src, scale, IMG_TOP_Y, 20)

    draw = ImageDraw.Draw(bg)
    center_text(draw, "Track Your Activity", TEXT_TOP_Y, FONT_TITLE, TEXT_WHITE)
    center_text(draw, "Log your movements and build healthy habits", TEXT_SUB_Y, FONT_SUBTITLE, TEXT_GRAY)

    bg.convert("RGB").save(os.path.join(OUT, "02_track_your_activity.png"), "PNG")
    print("Created 02_track_your_activity.png")


def create_screenshot_3():
    """Notification banner - 'Get Gentle Reminders'"""
    bg = make_gradient_bg()
    src = Image.open(FILE_3)

    # 720x148 — scale to about 2200px wide to be prominent
    scale = 2200 / src.width
    y_pos = (HEIGHT // 2) - int(src.height * scale // 2) + 80
    bg = compose(bg, src, scale, y_pos, 40)

    draw = ImageDraw.Draw(bg)
    center_text(draw, "Get Gentle Reminders", 200, FONT_TITLE, TEXT_WHITE)
    center_text(draw, "A nudge when it's time to move", 310, FONT_SUBTITLE, TEXT_GRAY)

    bg.convert("RGB").save(os.path.join(OUT, "03_gentle_reminders.png"), "PNG")
    print("Created 03_gentle_reminders.png")


def create_screenshot_4():
    """Notification with actions - 'Respond Your Way'"""
    bg = make_gradient_bg()
    src = Image.open(FILE_4)

    # 772x172 — scale to about 2200px wide
    scale = 2200 / src.width
    y_pos = (HEIGHT // 2) - int(src.height * scale // 2) + 80
    bg = compose(bg, src, scale, y_pos, 40)

    draw = ImageDraw.Draw(bg)
    center_text(draw, "Respond Your Way", 200, FONT_TITLE, TEXT_WHITE)
    center_text(draw, "Log activity, acknowledge, or snooze", 310, FONT_SUBTITLE, TEXT_GRAY)

    bg.convert("RGB").save(os.path.join(OUT, "04_respond_your_way.png"), "PNG")
    print("Created 04_respond_your_way.png")


if __name__ == "__main__":
    create_screenshot_1()
    create_screenshot_2()
    create_screenshot_3()
    create_screenshot_4()
    print(f"\nAll screenshots saved to: {OUT}")
