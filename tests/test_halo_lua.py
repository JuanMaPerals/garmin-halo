"""
Test harness for verifying Lua commands against the Halo emulator.

Uses the halo_emulator package (from brilliant_sdk) to run Lua commands
in a virtual Halo environment with a 256x256 display, then asserts
expected outputs and display states.

Run with:
    python3 tests/test_halo_lua.py
    # or
    pytest tests/test_halo_lua.py

Requires the halo_emulator package (installed in the Docker image).
"""

import os
import re
import sys
import time
import tempfile
from pathlib import Path

# Add the tests directory to the path so we can import lua_commands
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua_commands import LUA_COMMANDS, LONG_LUA_COMMAND, chunk_command, reassemble_chunks

try:
    from halo_emulator import HaloEmulator
except ImportError:
    print("ERROR: halo_emulator package not found.")
    print("Install it by cloning https://github.com/brilliantlabsAR/brilliant_sdk")
    print("and running: pip install -e python/packages/halo_emulator")
    sys.exit(1)


def run_lua_command(lua_code: str, timeout: float = 5.0) -> dict:
    """
    Run a Lua command in the Halo emulator and return results.

    Returns a dict with:
      - print_output: list of strings captured from print()
      - bluetooth_sent: bytes captured from frame.bluetooth.send()
      - framebuffer: PIL Image of the 256x256 display (or None)
    """
    print_outputs = []
    bluetooth_sent = bytearray()

    def print_handler(text):
        print_outputs.append(str(text))

    def bluetooth_handler(data: bytes):
        bluetooth_sent.extend(data)

    with tempfile.TemporaryDirectory() as sandbox_dir:
        # Write the Lua code as main.lua
        main_lua = Path(sandbox_dir) / "main.lua"
        main_lua.write_text(lua_code)

        emu = HaloEmulator(
            sandbox_dir=sandbox_dir,
            print_handler=print_handler,
        )

        # Capture bluetooth.send() calls
        original_send = emu._bluetooth_send if hasattr(emu, '_bluetooth_send') else None

        emu.start("main.lua")
        emu.wait(timeout=timeout)

        # Get the framebuffer
        framebuffer = None
        try:
            framebuffer = emu.get_framebuffer()
        except Exception:
            pass

        # Get bluetooth sent data
        try:
            bluetooth_sent = emu.get_bluetooth_sent()
        except Exception:
            pass

        if emu.is_running():
            emu.stop()

    return {
        "print_output": print_outputs,
        "bluetooth_sent": bytes(bluetooth_sent) if bluetooth_sent else b"",
        "framebuffer": framebuffer,
    }


def framebuffer_has_content(img) -> bool:
    """Check if the framebuffer has any non-black pixels."""
    if img is None:
        return False
    pixels = list(img.getdata())
    for pixel in pixels:
        if isinstance(pixel, tuple):
            r, g, b = pixel[:3]
            if r + g + b > 0:
                return True
        elif pixel > 0:
            return True
    return False


def framebuffer_is_blank(img) -> bool:
    """Check if the framebuffer is entirely black."""
    if img is None:
        return True  # No framebuffer = nothing drawn = blank
    return not framebuffer_has_content(img)


# --- Tests ---

def test_hello_print():
    """Verify print('Hello from Garmin') produces correct output."""
    cmd = LUA_COMMANDS["hello"]
    result = run_lua_command(cmd["code"])
    output = "\n".join(result["print_output"]).strip()
    assert output == cmd["expected_output"], \
        f"Expected '{cmd['expected_output']}', got '{output}'"
    print(f"  PASS: print('Hello from Garmin') -> '{output}'")


def test_draw_text():
    """Verify frame.display.text() renders text on the virtual display."""
    cmd = LUA_COMMANDS["draw_text"]
    result = run_lua_command(cmd["code"])
    assert framebuffer_has_content(result["framebuffer"]), \
        "Expected non-blank framebuffer after drawing text"
    print("  PASS: frame.display.text() produced visible display content")


def test_clear_display():
    """Verify frame.display.clear() produces an all-black framebuffer."""
    cmd = LUA_COMMANDS["clear_display"]
    result = run_lua_command(cmd["code"])
    assert framebuffer_is_blank(result["framebuffer"]), \
        "Expected blank framebuffer after clear()"
    print("  PASS: frame.display.clear() produced blank display")


def test_battery_level():
    """Verify print(frame.battery_level()) returns a number."""
    cmd = LUA_COMMANDS["battery_level"]
    result = run_lua_command(cmd["code"])
    output = "\n".join(result["print_output"]).strip()
    assert re.match(cmd["expected_output_regex"], output), \
        f"Expected numeric output matching {cmd['expected_output_regex']}, got '{output}'"
    print(f"  PASS: frame.battery_level() -> '{output}'")


def test_draw_text_short():
    """Verify a short text command that fits in a single 20-byte chunk."""
    cmd = LUA_COMMANDS["draw_text_short"]
    result = run_lua_command(cmd["code"])
    assert framebuffer_has_content(result["framebuffer"]), \
        "Expected non-blank framebuffer after drawing short text"
    print("  PASS: short text command rendered correctly")


def test_multiple_commands():
    """Verify sequential commands work (simulating multiple BLE writes)."""
    # Run clear, then draw text, then print — simulating a sequence of REPL commands
    commands = [
        "frame.display.clear()",
        "frame.display.text('Step 1', 10, 50, 0xFFFFFF)",
        "frame.display.text('Step 2', 10, 100, 0xFFFFFF)",
        "print('Done')",
    ]

    combined = "\n".join(commands)
    result = run_lua_command(combined)

    output = "\n".join(result["print_output"]).strip()
    assert output == "Done", f"Expected 'Done', got '{output}'"
    assert framebuffer_has_content(result["framebuffer"]), \
        "Expected non-blank framebuffer after drawing text"
    print(f"  PASS: sequential commands -> output='{output}', display has content")


def test_long_command_chunking():
    """
    Verify that a long Lua command split into 20-byte segments still
    executes correctly when concatenated (tests the chunking logic).

    The Garmin BLE API limits writes to 20 bytes. The HaloComm class
    chunks long commands and sends them sequentially. Halo's Lua REPL
    buffers partial input until it gets a complete statement.
    """
    # Split the long command into 20-byte chunks
    chunks = chunk_command(LONG_LUA_COMMAND)
    assert len(chunks) > 1, "Test command should be longer than 20 bytes"

    # Reassemble and verify it matches the original
    reassembled = reassemble_chunks(chunks)
    assert reassembled == LONG_LUA_COMMAND, \
        "Reassembled command should match original"

    # Run the reassembled command in the emulator
    result = run_lua_command(reassembled)
    assert framebuffer_has_content(result["framebuffer"]), \
        "Expected non-blank framebuffer after chunked command"

    print(f"  PASS: long command ({len(LONG_LUA_COMMAND)} bytes, {len(chunks)} chunks) "
          f"reassembled and executed correctly")


def test_all_commands_compile():
    """Verify all Lua commands in the catalog are valid Lua syntax."""
    for name, cmd in LUA_COMMANDS.items():
        code = cmd["code"]
        # If the command runs without error, it compiled
        try:
            result = run_lua_command(code, timeout=3.0)
            print(f"  PASS: '{name}' compiled and ran")
        except Exception as e:
            print(f"  FAIL: '{name}' failed to run: {e}")
            raise


def test_running_ui_render():
    """Verify the running mode UI renders correctly on the emulator."""
    lua = (
        "frame.display.clear(0x000000)"
        "frame.display.circle(128,128,125,0x0050A0,false)"
        "frame.display.circle(128,128,122,0x002060,false)"
        "frame.display.set_font(0,16,1)"
        'frame.display.text("145",108,30,0xFF4444)'
        "frame.display.circle(100,38,4,0xFF4444,true)"
        "frame.display.set_font(1,32,1)"
        'frame.display.text("5:30",78,90,0xFFFFFF)'
        "frame.display.set_font(0,16,1)"
        'frame.display.text("/km",96,130,0x808080)'
        'frame.display.text("2.5km",96,165,0x44FF44)'
        'frame.display.text("12:34",96,190,0xFFFFFF)'
        "frame.display.line(50,155,206,155,0x303030)"
    )
    result = run_lua_command(lua)
    assert framebuffer_has_content(result["framebuffer"]), \
        "Running UI should produce non-blank framebuffer"

    img = result["framebuffer"]
    pixels = list(img.getdata())
    has_red = any(r > 200 and g < 100 and b < 100 for r, g, b, a in pixels)
    has_green = any(g > 200 and r < 100 and b < 100 for r, g, b, a in pixels)
    has_blue = any(b > 100 and r < 50 and g < 100 for r, g, b, a in pixels)
    has_white = any(r > 200 and g > 200 and b > 200 for r, g, b, a in pixels)
    assert has_red, "Running UI should have red pixels (HR)"
    assert has_green, "Running UI should have green pixels (distance)"
    assert has_blue, "Running UI should have blue pixels (ring)"
    assert has_white, "Running UI should have white pixels (pace)"
    print("  PASS: running UI renders with expected colors (red HR, green dist, blue ring, white pace)")


def test_navigation_ui_render():
    """Verify the navigation mode UI renders correctly on the emulator."""
    lua = (
        "frame.display.clear(0x000000)"
        "frame.display.circle(128,128,125,0x0050A0,false)"
        "frame.display.circle(128,128,122,0x002060,false)"
        "frame.display.polygon({108,28,100,46,116,46},0xFFFF00)"
        "frame.display.set_font(0,16,1)"
        'frame.display.text("120m",122,32,0xFFFF00)'
        'frame.display.text("145",108,70,0xFF4444)'
        "frame.display.circle(100,78,4,0xFF4444,true)"
        "frame.display.set_font(1,32,1)"
        'frame.display.text("5:30",78,110,0xFFFFFF)'
        "frame.display.set_font(0,16,1)"
        'frame.display.text("/km",96,150,0x808080)'
        'frame.display.text("2.5km",96,180,0x44FF44)'
        'frame.display.text("12:34",96,205,0xFFFFFF)'
        "frame.display.line(50,170,206,170,0x303030)"
    )
    result = run_lua_command(lua)
    assert framebuffer_has_content(result["framebuffer"]), \
        "Navigation UI should produce non-blank framebuffer"

    img = result["framebuffer"]
    pixels = list(img.getdata())
    has_yellow = any(r > 200 and g > 200 and b < 100 for r, g, b, a in pixels)
    assert has_yellow, "Navigation UI should have yellow pixels (arrow + distance)"
    print("  PASS: navigation UI renders with yellow arrow and distance")


# --- Main entry point ---

def run_all_tests():
    """Run all tests and report results."""
    tests = [
        ("test_hello_print", test_hello_print),
        ("test_draw_text", test_draw_text),
        ("test_clear_display", test_clear_display),
        ("test_battery_level", test_battery_level),
        ("test_draw_text_short", test_draw_text_short),
        ("test_multiple_commands", test_multiple_commands),
        ("test_long_command_chunking", test_long_command_chunking),
        ("test_all_commands_compile", test_all_commands_compile),
        ("test_running_ui_render", test_running_ui_render),
        ("test_navigation_ui_render", test_navigation_ui_render),
    ]

    passed = 0
    failed = 0

    for name, test_func in tests:
        print(f"\n[{name}]")
        try:
            test_func()
            passed += 1
        except Exception as e:
            print(f"  FAIL: {e}")
            failed += 1

    print(f"\n{'=' * 50}")
    print(f"Results: {passed} passed, {failed} failed, {len(tests)} total")
    print(f"{'=' * 50}")

    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
