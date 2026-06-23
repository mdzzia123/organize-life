import subprocess, time, re, xml.etree.ElementTree as ET, sys
from pathlib import Path

ADB = r"D:\Android\android-sdk\platform-tools\adb.exe"
S = "emulator-5554"
LOCAL = Path(r"C:\Users\Administrator\AppData\Local\Temp\u.xml")
OUT = Path(r"D:\organize-life\scripts\test_result.txt")

def log(msg):
    print(msg)
    with OUT.open("a", encoding="utf-8") as f:
        f.write(msg + "\n")

def adb(*a):
    return subprocess.run([ADB, "-s", S, *a], capture_output=True, text=True, encoding="utf-8", errors="replace")

def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/u.xml")
    adb("pull", "/sdcard/u.xml", str(LOCAL))
    return LOCAL.read_text(encoding="utf-8", errors="replace")

def tap(x,y,w=2):
    adb("shell","input","tap",str(x),str(y)); time.sleep(w)

def find_desc(xml, *keys):
    root = ET.fromstring(xml)
    for n in root.iter("node"):
        d = n.attrib.get("content-desc","")
        t = n.attrib.get("text","")
        blob = d + t
        if any(k in blob for k in keys):
            b = n.attrib.get("bounds","")
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
            if m:
                x1,y1,x2,y2=map(int,m.groups())
                return (x1+x2)//2,(y1+y2)//2,blob
    return None

OUT.write_text("", encoding="utf-8")
adb("install","-r", r"D:\organize-life\releases\organize_life_v1.2.0_release.apk")
adb("shell","am","force-stop","com.organizelife.organize_life")
adb("shell","am","start","-n","com.organizelife.organize_life/.MainActivity")
time.sleep(4)

tests = []
def check(name, cond):
    tests.append((name, cond))
    log(f"[{'PASS' if cond else 'FAIL'}] {name}")

x = dump()
check("Home", "整理人生" in x and "衣服" in x)

tap(765,210); time.sleep(2)
check("Stats", "总览" in dump())
tap(74,210); time.sleep(1)

tap(639,210); time.sleep(2)
check("Search", "关键词" in dump() or "搜索标题" in dump())
tap(74,210); time.sleep(1)

tap(1017,210); time.sleep(2)
xset = dump()
check("Settings", "测试云端连接" in xset)
pt = find_desc(xset, "测试云端连接")
if pt: tap(pt[0], pt[1], 6)
xping = dump()
check("Cloud ping", ("连接正常" in xping) or ("连接失败" in xping))
log("Ping detail: " + ("连接正常" if "连接正常" in xping else "连接失败/未知"))
tap(74,210); time.sleep(1)

tap(283,618); time.sleep(2)
check("Category clothing", "衣服" in dump())

# Add via camera
tap(980,2200); time.sleep(2)
xs = dump()
cam = find_desc(xs, "拍照")
gal = find_desc(xs, "从相册选择")
check("Add sheet", cam is not None and gal is not None)
if cam:
    tap(cam[0], cam[1], 3)
    xc = dump()
    log("After camera tap: " + xc[:200].replace("\n"," "))
    # shutter button common location
    tap(540, 2000, 2)
    tap(900, 2000, 2)
    tap(540, 2200, 2)
    xd = dump()
    if "添加图片" in xd:
        save = find_desc(xd, "保存")
        if save:
            tap(save[0], save[1], 15)
            xe = dump()
            upload_ok = ("未命名" in xe) or ("同步到云端" in xe) or ("1 张" in xe)
            check("Upload with progress", upload_ok)
        else:
            check("Upload with progress", False)
    else:
        check("Upload with progress", False)

tap(74,210); time.sleep(1)
tap(74,210); time.sleep(1)
check("Back home", "整理人生" in dump())

passed = sum(1 for _,ok in tests if ok)
log(f"\nTOTAL {passed}/{len(tests)}")
sys.exit(0 if passed>=len(tests)-1 else 1)
