import subprocess, time, re, xml.etree.ElementTree as ET
from pathlib import Path

ADB = r"D:\Android\android-sdk\platform-tools\adb.exe"
S = "emulator-5554"
LOCAL = Path(r"C:\Users\Administrator\AppData\Local\Temp\u.xml")

def adb(*a):
    subprocess.run([ADB, "-s", S, *a], capture_output=True)

def dump(pkg_filter=None):
    adb("shell", "uiautomator", "dump", "/sdcard/u.xml")
    adb("pull", "/sdcard/u.xml", str(LOCAL))
    x = LOCAL.read_text(encoding="utf-8", errors="replace")
    return x

def tap(x,y,w=2):
    adb("shell","input","tap",str(x),str(y)); time.sleep(w)

def list_clickable(x):
    root = ET.fromstring(x)
    for n in root.iter("node"):
        if n.attrib.get("clickable") != "true":
            continue
        t = n.attrib.get("text","")
        d = n.attrib.get("content-desc","")
        b = n.attrib.get("bounds","")
        if t or d:
            print(t, "|", d, "|", b)

adb("shell","pm","grant","com.organizelife.organize_life","android.permission.CAMERA")
adb("shell","pm","grant","com.organizelife.organize_life","android.permission.READ_MEDIA_IMAGES")
adb("shell","am","force-stop","com.organizelife.organize_life")
adb("shell","am","start","-n","com.organizelife.organize_life/.MainActivity")
time.sleep(4)
tap(283,618); time.sleep(2)
tap(980,2200); time.sleep(2)
tap(540,2116); time.sleep(3)
print("=== CAMERA UI ===")
list_clickable(dump())
# common emulator camera shutter/done
for pos in [(540,2200),(900,2200),(980,2200),(540,2000),(850,2000)]:
    tap(*pos,2)
    x=dump()
    if "com.organizelife" in x and ("添加图片" in x or "保存" in x):
        print("DIALOG at", pos)
        tap(900,1700,15)
        print("FINAL", "未命名" in dump(), "1 张" in dump())
        break
    if "com.android.camera2" not in x:
        print("left camera at", pos, "pkg changed")
