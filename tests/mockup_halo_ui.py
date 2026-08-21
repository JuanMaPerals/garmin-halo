"""
Render mockup screenshots of the Halo running UI on the emulator.

Generates two PNGs:
  - mockup_running.png    - basic running mode (pace, HR, distance, time)
  - mockup_navigation.png - navigation mode (arrow + distance to next turn)

Run inside Docker:
    python3 tests/mockup_halo_ui.py
"""

import os
import sys
import tempfile
from pathlib import Path

try:
    from halo_emulator import HaloEmulator
except ImportError:
    print("ERROR: halo_emulator package not found.")
    sys.exit(1)


def render_mockup(lua_code: str, output_path: str, label: str):
    """Run Lua code on the emulator and save the framebuffer as PNG."""
    with tempfile.TemporaryDirectory() as sandbox:
        main_lua = Path(sandbox) / "main.lua"
        main_lua.write_text(lua_code)

        emu = HaloEmulator(sandbox_dir=sandbox)
        emu.start("main.lua")
        emu.wait(timeout=3.0)

        img = emu.get_framebuffer()
        if img is not None:
            img.save(output_path)
            print(f"[{label}] Saved to {output_path} ({img.size[0]}x{img.size[1]})")
        else:
            print(f"[{label}] ERROR: No framebuffer returned")

        if emu.is_running():
            emu.stop()


# Running mode: pace (center), HR (top-left), distance + time (bottom)
LUA_RUNNING = """
frame.display.clear(0x000000)
frame.display.circle(128, 128, 125, 0x0050A0, false)
frame.display.circle(128, 128, 122, 0x002060, false)
frame.display.set_font(0, 16, 1)
frame.display.text("145", 108, 30, 0xFF4444)
frame.display.circle(100, 38, 4, 0xFF4444, true)
frame.display.set_font(1, 32, 1)
frame.display.text("5:30", 78, 90, 0xFFFFFF)
frame.display.set_font(0, 16, 1)
frame.display.text("/km", 96, 130, 0x808080)
frame.display.text("2.5km", 96, 165, 0x44FF44)
frame.display.text("12:34", 96, 190, 0xFFFFFF)
frame.display.line(50, 155, 206, 155, 0x303030)
"""

# Navigation mode: arrow + distance to next turn at top, pace shifted down
LUA_NAVIGATION = """
frame.display.clear(0x000000)
frame.display.circle(128, 128, 125, 0x0050A0, false)
frame.display.circle(128, 128, 122, 0x002060, false)
frame.display.polygon({108, 28, 100, 46, 116, 46}, 0xFFFF00)
frame.display.set_font(0, 16, 1)
frame.display.text("120m", 122, 32, 0xFFFF00)
frame.display.text("145", 108, 70, 0xFF4444)
frame.display.circle(100, 78, 4, 0xFF4444, true)
frame.display.set_font(1, 32, 1)
frame.display.text("5:30", 78, 110, 0xFFFFFF)
frame.display.set_font(0, 16, 1)
frame.display.text("/km", 96, 150, 0x808080)
frame.display.text("2.5km", 96, 180, 0x44FF44)
frame.display.text("12:34", 96, 205, 0xFFFFFF)
frame.display.line(50, 170, 206, 170, 0x303030)
"""

if __name__ == "__main__":
    out_dir = Path(__file__).parent.parent / "mockups"
    out_dir.mkdir(exist_ok=True)

    print("=== Rendering Halo UI mockups ===")
    render_mockup(LUA_RUNNING, str(out_dir / "mockup_running.png"), "Running")
    render_mockup(LUA_NAVIGATION, str(out_dir / "mockup_navigation.png"), "Navigation")
    print("=== Done ===")
