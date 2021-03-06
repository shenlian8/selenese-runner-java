package jp.vmi.selenium.rollup;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import javax.script.ScriptEngine;
import javax.script.ScriptEngineManager;
import javax.script.ScriptException;

import jp.vmi.selenium.selenese.SeleneseRunnerRuntimeException;
import jp.vmi.selenium.selenese.utils.LangUtils;

/**
 * Set or rollup rules.
 */
public class RollupRules {

    private static enum EngineType {
        RHINO("Rhino"), NASHORN("Nashorn");

        public final String engineName;

        private EngineType(String engineName) {
            this.engineName = engineName;
        }

        public boolean matches(String name) {
            return LangUtils.containsIgnoreCase(name, engineName);
        }
    }

    final ScriptEngine engine;
    final EngineType engineType;
    private final Map<String, RollupRule> rollupRules = new HashMap<>();

    /**
     * Constructor.
     */
    public RollupRules() {
        engine = new ScriptEngineManager().getEngineByExtension("js");
        // some OpenJDK7 installations have lack of JavaScript support
        if (engine == null)
            throw new SeleneseRunnerRuntimeException("Script engine not found for js");
        String engineName = engine.getFactory().getEngineName();
        EngineType engineType = null;
        for (EngineType et : EngineType.values()) {
            if (et.matches(engineName)) {
                engineType = et;
                break;
            }
        }
        if (engineType == null)
            throw new SeleneseRunnerRuntimeException("Unknown script engine: " + engineName);
        this.engineType = engineType;
    }

    /**
     * Load rollup rule definitions.
     *
     * @param is InputStream object.
     */
    public void load(final InputStream is) {
        RollupManager.rollupRulesContext(this, new Runnable() {
            @Override
            public void run() {
                try {
                    String packageName = RollupManager.class.getPackage().getName();
                    if (engineType == EngineType.NASHORN)
                        engine.eval("load('nashorn:mozilla_compat.js');");
                    engine.eval("importPackage(Packages." + packageName + ");");
                    try (Reader r = new InputStreamReader(is, StandardCharsets.UTF_8)) {
                        engine.eval(r);
                    } catch (IOException e) {
                        // no operation.
                    }
                } catch (ScriptException e) {
                    throw new SeleneseRunnerRuntimeException(e);
                }
            }
        });
    }

    /**
     * Load rollup rule definitions.
     *
     * @param filename JavaScript file for rollup rule definitions.
     */
    public void load(String filename) {
        try {
            load(new FileInputStream(filename));
        } catch (FileNotFoundException e) {
            throw new SeleneseRunnerRuntimeException(e);
        }
    }

    /**
     * Add rollup rule.
     *
     * @param rule rollup rule.
     */
    public void addRule(Map<?, ?> rule) {
        rollupRules.put((String) rule.get("name"), new RollupRule(engine, rule));
    }

    /**
     * Get rollup rule.
     *
     * @param name rollup rule name.
     * @return IRollupRule object.
     */
    public IRollupRule get(String name) {
        return rollupRules.get(name);
    }
}
