using Toybox.Graphics as Gfx;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

// Shared 166 x 166 layout and badge helpers for the Instinct E 40 mm.
module JumpUi {
    // Main screen grid. Values are in pixels, y is the top of the text unless
    // the helper name says "center".
    const COUNT_CENTER = 64;
    const COUNT_Y = 2;
    const DIVIDER_Y = 54;
    const TIME_CENTER_Y = 67;
    const LABEL_Y = 82;
    const VALUE_Y = 102;
    const STATUS_Y = 125;
    const BOTTOM_Y = 145;
    const COL_X = [33, 83, 133] as Array<Number>;

    public function foreground(dark as Boolean) as Number {
        return dark ? Gfx.COLOR_WHITE : Gfx.COLOR_BLACK;
    }

    public function background(dark as Boolean) as Number {
        return dark ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE;
    }

    public function applyTheme(dc as Gfx.Dc, dark as Boolean) as Void {
        dc.setColor(foreground(dark), background(dark));
        dc.clear();
    }

    // Returns [centreX, centreY, radius]. The printed circular window is the
    // source of truth; the known Instinct E values are only a fallback.
    public function subscreen() as Array<Number> {
        if (Ui has :getSubscreen) {
            var s = Ui.getSubscreen();
            if (s != null) {
                var sx = s.x;
                var sy = s.y;
                if (sx instanceof Number && sy instanceof Number) {
                    return [
                        (sx as Number) + (s.width / 2),
                        (sy as Number) + (s.height / 2),
                        s.width / 2
                    ];
                }
            }
        }
        return [139, 26, 25];
    }

    // Normal state: foreground disc + background glyph. Rest/pause/target
    // flash: background disc + foreground glyph plus a ring. In dark mode this
    // keeps the badge visible against the black background.
    public function drawBadge(dc as Gfx.Dc, dark as Boolean, inverted as Boolean, progress as Float, glyph as Ui.BitmapResource?) as Void {
        var sub = subscreen();
        var cx = sub[0];
        var cy = sub[1];
        var r = sub[2] - 1;

        var fg = foreground(dark);
        var bg = background(dark);
        var discColor = inverted ? bg : fg;
        var glyphColor = inverted ? fg : bg;

        dc.setColor(discColor, discColor);
        dc.fillCircle(cx, cy, r);

        dc.setColor(glyphColor, discColor);
        if (inverted) {
            dc.setPenWidth(2);
            dc.drawCircle(cx, cy, r - 1);
        }

        if (progress > 0.0f) {
            dc.setPenWidth(3);
            if (progress >= 0.999f) {
                dc.drawCircle(cx, cy, r - 4);
            } else {
                var sweep = (progress * 360.0f).toNumber();
                if (sweep >= 3) {
                    var endDeg = 90 - sweep;
                    if (endDeg < 0) {
                        endDeg += 360;
                    }
                    dc.drawArc(cx, cy, r - 4, Gfx.ARC_CLOCKWISE, 90, endDeg);
                }
            }
            dc.setPenWidth(1);
        }

        if (glyph != null) {
            dc.setColor(glyphColor, discColor);
            dc.drawBitmap(cx - (glyph.getWidth() / 2), cy - (glyph.getHeight() / 2), glyph);
        }

        // Leave the drawing state ready for normal foreground-on-background
        // content in the selected theme.
        dc.setPenWidth(1);
        dc.setColor(fg, bg);
    }

    public function drawDivider(dc as Gfx.Dc, dark as Boolean) as Void {
        dc.setColor(foreground(dark), background(dark));
        dc.setPenWidth(1);
        dc.drawLine(0, DIVIDER_Y, dc.getWidth() - 1, DIVIDER_Y);
    }

    public function drawCenterText(dc as Gfx.Dc, cx as Number, centerY as Number, font as Gfx.FontType, text as String) as Void {
        var y = centerY - (dc.getFontHeight(font) / 2);
        dc.drawText(cx, y, font, text, Gfx.TEXT_JUSTIFY_CENTER);
    }

    public function drawMetric(dc as Gfx.Dc, dark as Boolean, col as Number, label as String, value as String) as Void {
        var cx = COL_X[col];
        dc.setColor(foreground(dark), background(dark));
        dc.drawText(cx, LABEL_Y, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, VALUE_Y, Gfx.FONT_SMALL, value, Gfx.TEXT_JUSTIFY_CENTER);
    }

    public function drawTrend(dc as Gfx.Dc, dark as Boolean, x as Number, y as Number, direction as Number) as Void {
        if (direction == 0) {
            return;
        }
        dc.setColor(foreground(dark), background(dark));
        if (direction > 0) {
            dc.drawLine(x - 3, y + 2, x + 3, y + 2);
            dc.drawLine(x + 3, y + 2, x, y - 3);
            dc.drawLine(x, y - 3, x - 3, y + 2);
        } else {
            dc.drawLine(x - 3, y - 2, x + 3, y - 2);
            dc.drawLine(x + 3, y - 2, x, y + 3);
            dc.drawLine(x, y + 3, x - 3, y - 2);
        }
    }
}
