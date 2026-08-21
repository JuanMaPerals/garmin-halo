import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Unit tests for HaloDisplay Lua script generation.
// Run with: make test
// Output is printed to console via System.println, prefixed with LUA_TEST:
// so the Python harness can capture and verify in the Halo emulator.
class HaloTests {

    // Test running mode with typical values
    (:test)
    function testRunningScript(logger as Test.Logger) as Boolean {
        var lua = HaloDisplay.buildRunningScriptFromValues(145, 3.0f, 2500.0f, 754000);
        System.println("LUA_TEST:RUNNING:" + lua);
        Test.assert(lua.length() > 0);
        logger.debug("Running script generated successfully");
        return true;
    }

    // Test navigation mode with distance to next point
    (:test)
    function testNavigationScript(logger as Test.Logger) as Boolean {
        var lua = HaloDisplay.buildNavigationScriptFromValues(145, 3.0f, 2500.0f, 754000, 120.0f);
        System.println("LUA_TEST:NAVIGATION:" + lua);
        Test.assert(lua.length() > 0);
        logger.debug("Navigation script generated successfully");
        return true;
    }

    // Test with null values (no GPS, no HR)
    (:test)
    function testNullValues(logger as Test.Logger) as Boolean {
        var lua = HaloDisplay.buildRunningScriptFromValues(null, null, null, null);
        System.println("LUA_TEST:NULL_VALUES:" + lua);
        Test.assert(lua.length() > 0);
        logger.debug("Null values handled correctly");
        return true;
    }

    // Test edge case: very high speed (sprint)
    (:test)
    function testSprintPace(logger as Test.Logger) as Boolean {
        var lua = HaloDisplay.buildRunningScriptFromValues(180, 7.0f, 100.0f, 15000);
        System.println("LUA_TEST:SPRINT:" + lua);
        Test.assert(lua.length() > 0);
        logger.debug("Sprint pace formatted correctly");
        return true;
    }

    // Test edge case: long distance (marathon)
    (:test)
    function testMarathonDistance(logger as Test.Logger) as Boolean {
        var lua = HaloDisplay.buildRunningScriptFromValues(150, 3.5f, 42195.0f, 12600000);
        System.println("LUA_TEST:MARATHON:" + lua);
        Test.assert(lua.length() > 0);
        logger.debug("Marathon distance and time formatted correctly");
        return true;
    }
}
