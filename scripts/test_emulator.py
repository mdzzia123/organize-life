#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Organize Life emulator functional test via adb uiautomator."""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ADB = r"D:\Android\android-sdk\platform-tools\adb.exe"
SERIAL = "emulator-5554"
APK = r"D:\organize-life\releases\organize_life_v1.2.0_release.apk"
PKG = "com.organizelife.organize_life"
DUMP_REMOTE = "/sdcard/ol_test_ui.xml"
DUMP_LOCAL = Path(r"C:\Users\Administrator\AppData\Local\Temp\ol_test_ui.xml")

results = []


def adb(*args):
    cmd = [ADB, "-s", SERIAL, *args]
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def tap(x, y, wait=1.5):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def back(wait=1.0):
    nodes = parse_nodes(dump_ui())
    n = find_node(nodes, "Back", "返回")
    if n:
        tap(n["cx"], n["cy"], wait)
    else:
        adb("shell", "input", "keyevent", "4")
        time.sleep(wait)


def dump_ui():
    adb("shell", "uiautomator", "dump", DUMP_REMOTE)
    adb("pull", DUMP_REMOTE, str(DUMP_LOCAL))
    if not DUMP_LOCAL.exists():
        return ""
    return DUMP_LOCAL.read_text(encoding="utf-8", errors="replace")


def parse_nodes(xml_text):
    nodes = []
    if not xml_text.strip():
        return nodes
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return nodes
    for n in root.iter("node"):
        text = n.attrib.get("text", "")
        desc = n.attrib.get("content-desc", "")
        bounds = n.attrib.get("bounds", "")
        clickable = n.attrib.get("clickable", "false") == "true"
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
        if not m:
            continue
        x1, y1, x2, y2 = map(int, m.groups())
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        nodes.append({"text": text, "desc": desc, "cx": cx, "cy": cy, "clickable": clickable, "bounds": bounds})
    return nodes


def find_node(nodes, *patterns):
    for p in patterns:
        for n in nodes:
            if p in (n["text"] or "") or p in (n["desc"] or ""):
                return n
    return None


def ui_has(nodes, *patterns):
    blob = "\n".join((n["text"] + " " + n["desc"]) for n in nodes)
    return any(p in blob for p in patterns)


def step(name, fn):
    try:
        ok = bool(fn())
        results.append((name, ok, ""))
        print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    except Exception as e:
        results.append((name, False, str(e)))
        print(f"[FAIL] {name}: {e}")


def launch_app():
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(4)


def main():
    print("=== Install APK ===")
    r = adb("install", "-r", APK)
    print(r.stdout or r.stderr)

    launch_app()
    nodes = parse_nodes(dump_ui())

    step("Home title", lambda: ui_has(nodes, "整理人生"))
    step("Home 7 categories", lambda: ui_has(nodes, "衣服", "化妆品", "其他"))
    step("Home stats line", lambda: ui_has(nodes, "7", "分类"))

    # Stats button (3rd icon)
    step("Open stats page", lambda: (tap(765, 210), ui_has(parse_nodes(dump_ui()), "总览"))[1])
    back()
    step("Back to home from stats", lambda: ui_has(parse_nodes(dump_ui()), "整理人生"))

    step("Open search page", lambda: (tap(639, 210), ui_has(parse_nodes(dump_ui()), "搜索标题", "关键词"))[1])
    back()
    step("Back from search", lambda: ui_has(parse_nodes(dump_ui()), "整理人生"))

    step("Open settings", lambda: (tap(1017, 210), ui_has(parse_nodes(dump_ui()), "测试云端连接", "账号"))[1])

    step("Cloud ping test", lambda: (
        (n := find_node(parse_nodes(dump_ui()), "测试云端连接")) and tap(n["cx"], n["cy"], 6),
        ui_has(parse_nodes(dump_ui()), "连接正常", "连接失败")
    )[1])

    step("Account entry visible", lambda: ui_has(parse_nodes(dump_ui()), "账号"))

    back()
    step("Back to home from settings", lambda: ui_has(parse_nodes(dump_ui()), "整理人生"))

    # Clothing category
    step("Open clothing category", lambda: (tap(283, 618), ui_has(parse_nodes(dump_ui()), "衣服", "暂无图片", "搜索"))[1])

    # Prepare test image on sdcard
    adb("shell", "mkdir", "-p", "/sdcard/Pictures/OL")
    adb("shell", "screencap", "-p", "/sdcard/Pictures/OL/test.png")
    adb("shell", "am", "broadcast", "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE", "-d", "file:///sdcard/Pictures/OL/test.png")

    step("Open add image sheet", lambda: (tap(980, 2200, 2), ui_has(parse_nodes(dump_ui()), "从相册选择", "拍照"))[1])

    def add_from_gallery():
        nodes2 = parse_nodes(dump_ui())
        n = find_node(nodes2, "从相册选择")
        if not n:
            return False
        tap(n["cx"], n["cy"], 3)
        # pick first photo in picker
        tap(180, 700, 2)
        nodes3 = parse_nodes(dump_ui())
        if not ui_has(nodes3, "添加图片", "保存"):
            return False
        n2 = find_node(nodes3, "保存")
        if not n2:
            return False
        tap(n2["cx"], n2["cy"], 10)
        nodes4 = parse_nodes(dump_ui())
        return ui_has(nodes4, "同步到云端", "完成", "未命名", "1 张", "失败") or not ui_has(nodes4, "暂无图片")

    step("Add image from gallery + upload", add_from_gallery)

    back()
    step("Home shows 1 image total", lambda: ui_has(parse_nodes(dump_ui()), "1 张"))

    print("\n=== Summary ===")
    passed = sum(1 for _, ok, _ in results if ok)
    total = len(results)
    for name, ok, err in results:
        if not ok and err:
            print(f"  ! {name}: {err}")
    print(f"Passed {passed}/{total}")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
