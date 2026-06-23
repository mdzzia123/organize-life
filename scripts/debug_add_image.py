import subprocess, time, re, xml.etree.ElementTree as ET
from pathlib import Path

ADB = r"D:\Android\android-sdk\platform-tools\adb.exe"
S = "emulator-5554"
LOCAL = Path(r"C:\Users\Administrator\AppData\Local\Temp\u.xml")

def adb(*a):
    return subprocess.run([ADB, "-s", S, *a], capture_output=True, text=True, encoding="utf-8", errors="replace")

def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/u.xml")
    adb("pull", "/sdcard/u.xml", str(LOCAL))
    return LOCAL.read_text(encoding="utf-8", errors="replace")

def tap(x,y,w=2):
    adb("shell","input","tap",str(x),str(y)); time.sleep(w)

# prepare image
adb("shell","mkdir","-p","/sdcard/Pictures/OL")
adb("shell","screencap","-p","/sdcard/Pictures/OL/test.png")
adb("shell","am","broadcast","-a","android.intent.action.MEDIA_SCANNER_SCAN_FILE","-d","file:///sdcard/Pictures/OL/test.png")
time.sleep(2)

adb("shell","am","force-stop","com.organizelife.organize_life")
adb("shell","am","start","-n","com.organizelife.organize_life/.MainActivity")
time.sleep(4)
tap(283,618)
time.sleep(2)
tap(980,2200)
time.sleep(2)
tap(540,2263)  # gallery option
time.sleep(4)
x = dump()
print("picker xml has test:", "test" in x.lower())
# print clickable nodes
root = ET.fromstring(x)
for n in root.iter("node"):
    d=n.attrib.get("content-desc",""); t=n.attrib.get("text","")
    b=n.attrib.get("bounds","")
    if n.attrib.get("clickable")=="true" and (d or t):
        print("click", t, d, b)

# tap grid area
for pos in [(180,700),(270,600),(540,900),(200,500)]:
    tap(*pos,2)
    x2=dump()
    if "添加图片" in x2:
        print("GOT DIALOG at", pos)
        tap(900, 1700) # save button area
        time.sleep(12)
        x3=dump()
        print("after save:", "未命名" in x3, "同步" in x3, "1 张" in x3)
        break
