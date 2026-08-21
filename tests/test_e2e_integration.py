#!/usr/bin/env python3
"""
End-to-end integration test: Connect IQ -> Lua generation -> Halo emulator.

This script:
1. Runs the Connect IQ unit tests (make test) in the Docker container
2. Captures LUA_TEST: lines from the simulator output
3. Feeds each generated Lua script into the Halo emulator
4. Verifies the framebuffer has expected content

Run with:
    python3 tests/test_e2e_integration.py
    # or inside Docker:
    docker-compose run --rm connectiq python3 tests/test_e2e_integration.py
"""

import os
import re
import sys
import subprocess
import tempfile
from pathlib import Path

# Add tests directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from halo_emulator import HaloEmulator
except ImportError:
    print("ERROR: halo_emulator package not found.")
    print("Install it by cloning https://github.com/brilliantlabsAR/brilliant_sdk")
    print("and running: pip install -e python/packages/halo_emulator")
    sys.exit(1)


def run_ciq_unit_tests() -> dict:
    """
    Run the Connect IQ unit tests and capture LUA_TEST output lines.

    Returns dict mapping test name -> Lua script string.
    """
    print("=== Running Connect IQ unit tests ===")

    # Run make test in the Docker container
    cmd = ["make", "test"]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=120,
    )

    output = result.stdout + result.stderr
    # make test may return non-zero due to killall, that's OK
    print(f"  make test exit code: {result.returncode}")

    # Parse LUA_TEST:TEST_NAME:lua_code lines
    lua_scripts = {}
    for line in output.splitlines():
        match = re.match(r"LUA_TEST:(\w+):(.*)", line)
        if match:
            test_name = match.group(1)
            # Unescape backslash-escaped quotes from System.println output
            lua_code = match.group(2).replace('\\"', '"')
            lua_scripts[test_name] = lua_code
            print(f"  Captured Lua script: {test_name} ({len(lua_code)} chars)")

    return lua_scripts


def run_lua_in_emulator(lua_code: str, timeout: float = 5.0) -> dict:
    """
    Run a Lua command in the Halo emulator and return results.

    Returns a dict with:
      - print_output: list of strings captured from print()
      - framebuffer: PIL Image of the 256x256 display (or None)
      - error: error message if execution failed (or None)
    """
    print_outputs = []

    def print_handler(text):
        print_outputs.append(str(text))

    with tempfile.TemporaryDirectory() as sandbox_dir:
        main_lua = Path(sandbox_dir) / "main.lua"
        main_lua.write_text(lua_code)

        emu = HaloEmulator(
            sandbox_dir=sandbox_dir,
            print_handler=print_handler,
        )

        try:
            emu.start("main.lua")
            emu.wait(timeout=timeout)
        except Exception as e:
            return {
                "print_output": print_outputs,
                "framebuffer": None,
                "error": str(e),
            }

        framebuffer = None
        try:
            framebuffer = emu.get_framebuffer()
        except Exception:
            pass

        if emu.is_running():
            emu.stop()

    return {
        "print_output": print_outputs,
        "framebuffer": framebuffer,
        "error": None,
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


def framebuffer_has_color(img, r_min, g_min, b_min, r_max, g_max, b_max) -> bool:
    """Check if the framebuffer has at least one pixel in the given color range."""
    if img is None:
        return False
    pixels = list(img.getdata())
    for pixel in pixels:
        if isinstance(pixel, tuple):
            r, g, b = pixel[:3]
            if r_min <= r <= r_max and g_min <= g <= g_max and b_min <= b <= b_max:
                return True
    return False


def verify_running_ui(result: dict) -> bool:
    """Verify the running UI framebuffer has expected colors."""
    if result["error"]:
        print(f"  FAIL: emulator error: {result['error']}")
        return False

    img = result["framebuffer"]
    if not framebuffer_has_content(img):
        print("  FAIL: framebuffer is blank")
        return False

    # Check for expected colors
    has_red = framebuffer_has_color(img, 200, 0, 0, 255, 100, 100)
    has_blue = framebuffer_has_color(img, 0, 0, 100, 50, 100, 200)
    has_white = framebuffer_has_color(img, 200, 200, 200, 255, 255, 255)

    if not has_red:
        print("  FAIL: no red pixels found (expected for HR)")
        return False
    if not has_blue:
        print("  FAIL: no blue pixels found (expected for ring)")
        return False
    if not has_white:
        print("  FAIL: no white pixels found (expected for pace)")
        return False

    print("  PASS: running UI has red (HR), blue (ring), white (pace)")
    return True


def verify_navigation_ui(result: dict) -> bool:
    """Verify the navigation UI framebuffer has expected colors."""
    if result["error"]:
        print(f"  FAIL: emulator error: {result['error']}")
        return False

    img = result["framebuffer"]
    if not framebuffer_has_content(img):
        print("  FAIL: framebuffer is blank")
        return False

    has_yellow = framebuffer_has_color(img, 200, 200, 0, 255, 255, 100)
    if not has_yellow:
        print("  FAIL: no yellow pixels found (expected for nav arrow)")
        return False

    print("  PASS: navigation UI has yellow (nav arrow)")
    return True


def verify_null_values(result: dict) -> bool:
    """Verify the null-values UI renders (should still have ring)."""
    if result["error"]:
        print(f"  FAIL: emulator error: {result['error']}")
        return False

    img = result["framebuffer"]
    if not framebuffer_has_content(img):
        print("  FAIL: framebuffer is blank")
        return False

    has_blue = framebuffer_has_color(img, 0, 0, 100, 50, 100, 200)
    if not has_blue:
        print("  FAIL: no blue pixels found (expected for ring)")
        return False

    print("  PASS: null-values UI has blue ring")
    return True


def verify_generic(result: dict) -> bool:
    """Generic verification: just check framebuffer is non-blank."""
    if result["error"]:
        print(f"  FAIL: emulator error: {result['error']}")
        return False

    if not framebuffer_has_content(result["framebuffer"]):
        print("  FAIL: framebuffer is blank")
        return False

    print("  PASS: framebuffer has content")
    return True


# Map test names to verification functions
VERIFIERS = {
    "RUNNING": verify_running_ui,
    "NAVIGATION": verify_navigation_ui,
    "NULL_VALUES": verify_null_values,
    "SPRINT": verify_generic,
    "MARATHON": verify_generic,
}


def main():
    print("=" * 60)
    print("End-to-End Integration Test: Connect IQ -> Halo Emulator")
    print("=" * 60)
    print()

    # Step 1: Run Connect IQ unit tests and capture Lua scripts
    lua_scripts = run_ciq_unit_tests()

    if not lua_scripts:
        print("\nFAIL: No LUA_TEST lines captured from unit tests.")
        print("Make sure the Connect IQ unit tests compile and run.")
        sys.exit(1)

    print(f"\nCaptured {len(lua_scripts)} Lua scripts from Connect IQ unit tests.")
    print()

    # Step 2: Run each Lua script in the Halo emulator and verify
    passed = 0
    failed = 0

    # Ensure mockups directory exists for saving PNGs
    mockups_dir = Path("mockups")
    mockups_dir.mkdir(exist_ok=True)

    for test_name, lua_code in lua_scripts.items():
        print(f"\n[{test_name}]")
        print(f"  Lua length: {len(lua_code)} chars")

        result = run_lua_in_emulator(lua_code)

        # Save framebuffer as PNG
        if result["framebuffer"] is not None:
            png_path = mockups_dir / f"e2e_{test_name.lower()}.png"
            result["framebuffer"].save(str(png_path))
            print(f"  Saved: {png_path}")

        verifier = VERIFIERS.get(test_name, verify_generic)
        if verifier(result):
            passed += 1
        else:
            failed += 1

    # Step 3: Report results
    print()
    print("=" * 60)
    print(f"E2E Results: {passed} passed, {failed} failed, {len(lua_scripts)} total")
    print("=" * 60)

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
