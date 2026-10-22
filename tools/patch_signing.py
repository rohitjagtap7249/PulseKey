import re
import sys

PATH = "android/app/build.gradle"

try:
    text = open(PATH, encoding="utf-8").read()
except FileNotFoundError:
    sys.exit("android/app/build.gradle not found")

if "signingConfigs.release" in text:
    print("already patched")
    sys.exit(0)

block = (
    "    signingConfigs {\n"
    "        release {\n"
    "            storeFile file(System.getenv(\"KEYSTORE_PATH\"))\n"
    "            storePassword System.getenv(\"KEYSTORE_PASSWORD\")\n"
    "            keyAlias System.getenv(\"KEY_ALIAS\")\n"
    "            keyPassword System.getenv(\"KEY_PASSWORD\")\n"
    "        }\n"
    "    }\n\n"
)

pattern = re.compile(r"^([ \t]*)buildTypes\s*\{", re.MULTILINE)
if not pattern.search(text):
    sys.exit("buildTypes block not found")

text = pattern.sub(lambda m: block + m.group(0), text, count=1)
text, n = re.subn(
    r"signingConfig\s+signingConfigs\.debug",
    "signingConfig signingConfigs.release",
    text,
)
if n == 0:
    sys.exit("debug signing line not found")

open(PATH, "w", encoding="utf-8").write(text)
print("patched signing config")
