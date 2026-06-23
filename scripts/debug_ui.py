import subprocess, time, re, xml.etree.ElementTree as ET
from pathlib import Path

ADB = r"D:\Android\android-sdk\platform-tools\adb.exe"
S = "emulator-5554"
LOCAL = Path(r"C:\Users\Administrator\AppData\Local\Temp\u.xml")

def adb(*a):
    subprocess.run([ADB, "-s", S, *a], capture_output=True)

def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/u.xml")
    adb("pull", "/sdcard/u.xml", str(LOCAL))
    return LOCAL.read_text(encoding="utf-8", errors="replace")

def nodes(xml):
    out = []
    root = ET.fromstring(xml)
    for n in root.iter("node"):
        desc = n.attrib.get("content-desc", "")
        text = n.attrib.get("text", "")
        b = n.attrib.get("bounds", "")
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
        if m:
            x1,y1,x2,y2 = map(int, m.groups())
            out.append((text, desc, (x1+x2)//2, (y1+y2)//2, b))
    return out

adb("shell", "am", "force-stop", "com.organizelife.organize_life")
adb("shell", "am", "start", "-n", "com.organizelife.organize_life/.MainActivity")
time.sleep(4)
adb("shell", "input", "tap", "639", "210")
time.sleep(2)
for t,d,cx,cy,b in nodes(dump()):
    if d or t:
        print("SEARCH NODE:", repr(t), repr(d), cx, cy)

# try top-left back
adb("shell", "input", "tap", "63", "210")
time.sleep(1)
print("tap back arrow home?", "整理人生" in dump())
