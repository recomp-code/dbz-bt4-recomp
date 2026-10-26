package io.github.recompcode.dbzbt4;

import org.json.JSONArray;
import org.json.JSONObject;

// The little JSON the bridge needs (org.json is part of Android).
final class Json {
    // A JSON string value -> the string ("" for anything else).
    static String str(String json) {
        try { return (String) new JSONArray("[" + json + "]").get(0); } catch (Exception e) { return ""; }
    }

    static String[] strArray(String json, String key) {
        try {
            JSONArray a = new JSONObject(json).getJSONArray(key);
            String[] out = new String[a.length()];
            for (int i = 0; i < a.length(); i++) out[i] = a.getString(i);
            return out;
        } catch (Exception e) { return new String[0]; }
    }

    // Non-ASCII as JSON unicode escapes: the strings cross JNI as modified UTF-8.
    static String ascii(String s) {
        StringBuilder b = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c < 0x80) b.append(c); else b.append(String.format("\\u%04x", (int) c));
        }
        return b.toString();
    }
}
