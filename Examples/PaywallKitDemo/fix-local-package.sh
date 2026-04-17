#!/bin/bash
# Patch pbxproj do XcodeGen generate thiếu field `package = ...` trong
# XCSwiftPackageProductDependency khi dùng local Swift Package.
#
# Lỗi Xcode: "Missing package product 'PaywallKitUI'".
# Chạy sau mỗi lần `xcodegen generate`.

set -euo pipefail

PBXPROJ="PaywallKitDemo.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "❌ $PBXPROJ không tồn tại. Chạy 'xcodegen generate' trước."
    exit 1
fi

# Lấy uuid của XCLocalSwiftPackageReference trỏ về "../.." (root package)
LOCAL_REF_UUID=$(grep -E "XCLocalSwiftPackageReference \"\\.\\./\\.\\.\"" "$PBXPROJ" \
    | head -1 \
    | grep -oE '[A-F0-9]{24}' \
    | head -1)

if [ -z "$LOCAL_REF_UUID" ]; then
    echo "❌ Không tìm thấy XCLocalSwiftPackageReference \"../..\" trong pbxproj."
    exit 1
fi

echo "🔧 Local package ref UUID: $LOCAL_REF_UUID"

# Thêm `package = <uuid> /* XCLocalSwiftPackageReference "../.." */;` vào mỗi
# XCSwiftPackageProductDependency chưa có field này.
python3 - <<PYTHON
import re, sys
path = "$PBXPROJ"
with open(path, "r") as f:
    content = f.read()

ref_uuid = "$LOCAL_REF_UUID"
pattern = re.compile(
    r'(\w+ /\* (?P<name>\w+) \*/ = \{\s*\n\s*isa = XCSwiftPackageProductDependency;\s*\n)(\s*productName = \w+;)',
    re.MULTILINE
)

def replace(match):
    head, product = match.group(1), match.group(3)
    if "package = " in match.group(0):
        return match.group(0)
    return head + f'\t\t\tpackage = {ref_uuid} /* XCLocalSwiftPackageReference "../.." */;\n' + product

new_content, count = pattern.subn(replace, content)
with open(path, "w") as f:
    f.write(new_content)
print(f"✅ Patched {count} XCSwiftPackageProductDependency entries.")
PYTHON

echo "✅ Xong. Mở Xcode và build."
