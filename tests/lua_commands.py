"""
Shared catalog of Lua commands used by both the Garmin Connect IQ app
and the Python test harness (test_halo_lua.py).

Each command has:
  - code: the Lua code string sent to Halo's Lua REPL
  - expected_output: expected print() output (None if no output expected)
  - expected_output_regex: regex pattern for output (used when output is variable)
  - expect_display_nonblank: if True, the framebuffer should have non-black pixels
  - expect_display_blank: if True, the framebuffer should be all black
  - description: human-readable description of what the command does
"""

LUA_COMMANDS = {
    "hello": {
        "code": "print('Hello from Garmin')",
        "expected_output": "Hello from Garmin",
        "expected_output_regex": None,
        "expect_display_nonblank": False,
        "expect_display_blank": False,
        "description": "Send a simple print() command and verify output",
    },
    "draw_text": {
        "code": "frame.display.clear() frame.display.text('Hello from Garmin', 50, 128, 0xFFFFFF)",
        "expected_output": None,
        "expected_output_regex": None,
        "expect_display_nonblank": True,
        "expect_display_blank": False,
        "description": "Draw text on Halo's virtual display",
    },
    "clear_display": {
        "code": "frame.display.clear()",
        "expected_output": None,
        "expected_output_regex": None,
        "expect_display_nonblank": False,
        "expect_display_blank": True,
        "description": "Clear the display and verify framebuffer is all black",
    },
    "battery_level": {
        "code": "print(frame.battery_level())",
        "expected_output": None,
        "expected_output_regex": r"\d+",
        "expect_display_nonblank": False,
        "expect_display_blank": False,
        "description": "Query battery level and verify numeric output",
    },
    "draw_text_short": {
        "code": "frame.display.text('Hi', 50, 128, 0xFFFFFF)",
        "expected_output": None,
        "expected_output_regex": None,
        "expect_display_nonblank": True,
        "expect_display_blank": False,
        "description": "Draw short text on display (fits in single 20-byte chunk)",
    },
}

# Long command that exceeds the 20-byte BLE write limit
# Used to test the chunking logic
LONG_LUA_COMMAND = (
    "frame.display.clear() "
    "frame.display.text('Hello from Garmin', 50, 128, 0xFFFFFF)"
)

# The same command split into 20-byte chunks as the Garmin would send it
CHUNK_SIZE = 20


def chunk_command(code: str) -> list[bytes]:
    """Split a Lua command string into 20-byte chunks as the Garmin BLE API would."""
    data = code.encode("utf-8")
    return [data[i:i + CHUNK_SIZE] for i in range(0, len(data), CHUNK_SIZE)]


def reassemble_chunks(chunks: list[bytes]) -> str:
    """Reassemble 20-byte chunks back into a single Lua command string."""
    return b"".join(chunks).decode("utf-8")
