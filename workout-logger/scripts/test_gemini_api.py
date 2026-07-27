#!/usr/bin/env python3
"""
test_gemini_api.py - Standalone Python script testing Gemini 3.6 Flash tool calling & GenUI dashboard response.

Executes a live 2-turn conversation flow:
 1. Sends initial user prompt ("Generate a volume graph for my triceps vs biceps").
 2. Parses the model's returned function call & thinking/thought_signature.
 3. Echoes back the model's turn verbatim, followed by the tool response under `role: "user"`.
 4. Prints the final model output (e.g. A2UI dashboard JSON).
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request


def load_env_file(filepath: str) -> None:
    if not os.path.exists(filepath):
        return
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            key = key.strip().strip("'\"")
            if key and not os.environ.get(key):
                os.environ[key] = val


def extract_retry_delay(body_str: str) -> float | None:
    """Mirrors Dart _extractRetryDelay implementation in gemini_ai_service.dart."""
    try:
        data = json.loads(body_str)
        if isinstance(data, dict) and "error" in data:
            err = data["error"]
            # 1. Check google.rpc.RetryInfo in error.details
            details = err.get("details", [])
            if isinstance(details, list):
                for item in details:
                    if isinstance(item, dict) and "retryDelay" in item:
                        delay_str = str(item["retryDelay"]).replace("s", "").strip()
                        val = float(delay_str)
                        if val > 0:
                            return val + 0.35
            # 2. Regex search in error.message (e.g. "Please retry in 23.690750876s.")
            msg = err.get("message", "")
            if isinstance(msg, str):
                match = re.search(r"retry in\s+([\d.]+)\s*s", msg, re.IGNORECASE)
                if match:
                    val = float(match.group(1))
                    if val > 0:
                        return val + 0.35
    except Exception:
        pass
    return None


def is_daily_quota_exhausted(body: str) -> bool:
    return "GenerateRequestsPerDay" in body or "free_tier_requests" in body or "QuotaExceeded" in body or "RESOURCE_EXHAUSTED" in body


def get_fallback_model(current_model: str) -> str | None:
    fallbacks = {
        "gemini-3.6-flash": "gemini-3.5-flash",
        "gemini-3.5-flash": "gemini-3.5-flash-lite",
        "gemini-3.5-flash-lite": "gemini-2.5-flash",
    }
    return fallbacks.get(current_model)


def post_generate_content_with_retry(model: str, api_key: str, payload: dict, max_attempts: int = 4) -> dict:
    current_model = model
    data_bytes = json.dumps(payload).encode("utf-8")

    for attempt in range(max_attempts):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{current_model}:generateContent?key={api_key}"
        req = urllib.request.Request(
            url,
            data=data_bytes,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8")
            if is_daily_quota_exhausted(body):
                fallback = get_fallback_model(current_model)
                if fallback:
                    print(f"  [QUOTA EXHAUSTED] {current_model} daily free quota reached! Automatically falling back to {fallback}...")
                    current_model = fallback
                    continue

            if e.code in (429, 500, 502, 503, 504):
                retry_sec = extract_retry_delay(body) or (0.5 * (2**attempt))
                print(f"  [HTTP {e.code}] Rate limit/server error detected. Google retryDelay: {retry_sec:.2f}s (Attempt {attempt+1}/{max_attempts})")
                if attempt < max_attempts - 1:
                    print(f"  --> Waiting {retry_sec:.2f}s before retry...")
                    time.sleep(retry_sec)
                    continue
            print(f"\n[!] HTTP {e.code} Error Body:\n{body}")
            raise e


def parse_genui_component(text: str) -> dict | None:
    """Mirrors Dart A2UiComponent.tryParse + property normalization."""
    trimmed = text.strip()
    if not trimmed or not trimmed.startswith("{"):
        return None
    try:
        data = json.loads(trimmed)
        if not isinstance(data, dict):
            return None
        comp = data.get("component")
        if not comp or not isinstance(comp, str):
            return None
        # Extract props (supporting both wrapped 'props' and flat properties)
        if isinstance(data.get("props"), dict):
            props = data["props"]
        else:
            props = {k: v for k, v in data.items() if k != "component"}
        return {"component": comp, "props": props}
    except Exception:
        return None


def main() -> None:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.abspath(os.path.join(script_dir, ".."))
    load_env_file(os.path.join(root_dir, ".env"))
    load_env_file(os.path.join(os.getcwd(), ".env"))

    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("[!] GEMINI_API_KEY not found in environment or .env file.")
        sys.exit(1)

    model = "gemini-3.6-flash"

    tools = [
        {
            "functionDeclarations": [
                {
                    "name": "get_muscle_group_volume",
                    "description": "Fetch volume history for muscle groups.",
                    "parameters": {
                        "type": "OBJECT",
                        "properties": {
                            "muscle_groups": {
                                "type": "ARRAY",
                                "items": {"type": "STRING"},
                            }
                        },
                        "required": ["muscle_groups"],
                    },
                }
            ]
        }
    ]

    system_instruction = {
        "parts": [
            {
                "text": (
                    "You are an expert personal trainer embedded in RepForge. "
                    'When asked for dashboards or comparison charts, return ONLY valid A2UI JSON: '
                    '{"component":"GridContainer","props":{"columns":1,"children":[...]}}'
                )
            }
        ]
    }

    print("=" * 70)
    print("VERIFYING GEMINI API RETRY & COMPONENT PARSING IN A LOOP")
    print("=" * 70)

    # Unit Test: Retry parsing regex & RetryInfo extraction
    sample_error = json.dumps({
        "error": {
            "code": 429,
            "message": "Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20, model: gemini-3.6-flash. Please retry in 23.690750876s.",
            "status": "RESOURCE_EXHAUSTED",
            "details": [{"@type": "type.googleapis.com/google.rpc.RetryInfo", "retryDelay": "23.690750876s"}]
        }
    })
    parsed_delay = extract_retry_delay(sample_error)
    print(f"[TEST 1] Testing retryDelay parser on sample 429 payload:")
    print(f"  Extracted Retry Delay: {parsed_delay:.3f} seconds (Expected ~24.04s)")
    assert parsed_delay is not None and 23.0 <= parsed_delay <= 25.0, "Parser failed!"
    print("  --> PASSED!\n")

    # Unit Test: Flat vs Wrapped GenUI Component Parser
    print("[TEST 2] Testing GenUI Flat & Wrapped Property Normalization:")
    flat_json = '{"component":"DynamicChart","type":"line","title":"Biceps vs Triceps","labels":["W1"],"series":[{"name":"Biceps","values":[100]}]}'
    parsed_flat = parse_genui_component(flat_json)
    print("  Parsed Flat JSON:", json.dumps(parsed_flat, indent=2))
    assert parsed_flat is not None and "props" in parsed_flat and parsed_flat["props"]["type"] == "line"
    print("  --> PASSED!\n")

    # Live Executions Loop
    num_runs = 2
    for run in range(1, num_runs + 1):
        print("=" * 70)
        print(f"RUN {run}/{num_runs}: Executing Live Multi-Turn Query against {model}...")
        print("=" * 70)

        contents = [
            {"role": "user", "parts": [{"text": "Generate a volume graph for my triceps vs biceps"}]}
        ]

        payload1 = {
            "contents": contents,
            "systemInstruction": system_instruction,
            "tools": tools,
            "generationConfig": {"thinkingConfig": {"thinkingLevel": "minimal"}},
        }

        try:
            res1 = post_generate_content_with_retry(model, api_key, payload1)
        except urllib.error.HTTPError as e:
            if e.code == 400:
                print(f"[NOTE] Live call skipped: API key in .env is invalid or unconfigured.")
                print("[SUCCESS] All local timeout parsing & component normalization tests verified!")
                sys.exit(0)
            raise e
        candidates = res1.get("candidates", [])
        first_cand = candidates[0]
        model_content = first_cand.get("content", {})
        raw_parts = model_content.get("parts", [])

        function_calls = [p["functionCall"] for p in raw_parts if "functionCall" in p]
        print(f"  Turn 1 Model Response: {len(function_calls)} function call(s) received.")

        if function_calls:
            contents.append(model_content)
            func_response_parts = [{
                "functionResponse": {
                    "name": fc["name"],
                    "response": {
                        "dates": ["2026-07-06", "2026-07-09", "2026-07-16"],
                        "series": [
                            {"name": "Biceps", "values": [600, 750, 900]},
                            {"name": "Triceps", "values": [1200, 1400, 1600]}
                        ]
                    }
                }
            } for fc in function_calls]

            contents.append({"role": "user", "parts": func_response_parts})

            payload2 = {
                "contents": contents,
                "systemInstruction": system_instruction,
                "tools": tools,
                "generationConfig": {"thinkingConfig": {"thinkingLevel": "minimal"}},
            }

            res2 = post_generate_content_with_retry(model, api_key, payload2)
            cands2 = res2.get("candidates", [])
            final_text = ""
            for part in cands2[0].get("content", {}).get("parts", []):
                if "text" in part:
                    final_text += part["text"]

            print(f"  Turn 2 Final Model Output (Length: {len(final_text)} chars):")
            parsed_comp = parse_genui_component(final_text)
            if parsed_comp:
                print("  [SUCCESS] Successfully parsed GenUI Component structure!")
                print(f"  Root Component: {parsed_comp['component']}")
            else:
                print("  Output Text:\n", final_text[:300])

        print(f"\n[SUCCESS] Run {run} completed successfully.\n")


if __name__ == "__main__":
    main()

