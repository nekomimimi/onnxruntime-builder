#!/usr/bin/env bash
set -eu

if [ ! -v IOS_X86_64_PATH ]; then # X86_64用のモジュールのディレクトリ(simulator)
    echo "IOS_X86_64_PATHが未定義です"
    exit 1
fi
if [ ! -v IOS_AARCH64_SIM_PATH ]; then # AARCH64_SIM用のモジュールのディレクトリ(simulator)
    echo "IOS_AARCH64_SIM_PATHが未定義です"
    exit 1
fi
if [ ! -v IOS_AARCH64_PATH ]; then # AARCH64用のモジュールのディレクトリ(実機)
    echo "IOS_AARCH64_PATHが未定義です"
    exit 1
fi
if [ ! -v ONNXRUNTIME_BASENAME ]; then # ONNXRUNTIMEファイル名
    echo "ONNXRUNTIME_BASENAMEが未定義です"
    exit 1
fi

echo "Remove no version notation dylib"
rm -f ${IOS_X86_64_PATH}/lib/*onnxruntime.dylib
rm -f ${IOS_AARCH64_SIM_PATH}/lib/*onnxruntime.dylib
rm -f ${IOS_AARCH64_PATH}/lib/*onnxruntime.dylib

echo "* Copy Framework template"
arches=("aarch64" "sim")
artifacts=("${IOS_AARCH64_PATH}" "${IOS_AARCH64_SIM_PATH}")
# mkdir -p "Framework-aarch64"
# cp -vr xcframework/Frameworks/aarch64/ Framework-aarch64/
# cp -v "${{ env.IOS_AARCH64_PATH }}/lib/${{ env.ONNXRUNTIME_BASENAME }}" \
# "Framework-aarch64/onnxruntime.framework/onnxruntime"
for i in "${!arches[@]}"; do
    arch="${arches[$i]}"
    artifact="${artifacts[$i]}"
    echo "* Copy Framework-${arch} template"
    mkdir -p "Framework-${arch}"
    cp -vr "xcframework/Frameworks/aarch64/${arch}/" "Framework-${arch}/"
done

echo "* Create dylib"
# aarch64はdylibをコピー
cp -v "${{ env.IOS_AARCH64_PATH }}/lib/${{ONNXRUNTIME_BASENAME }}" \
            "Framework-aarch64/onnxruntime.framework/onnxruntime"

# simはx86_64とarrch64を合わせてdylib作成
mkdir -p "artifact/onnxruntime-sim"
lipo -create "${IOS_X86_64_PATH}/lib/${ONNXRUNTIME_BASENAME}" \
    "${IOS_AARCH64_SIM_PATH}/lib/${ONNXRUNTIME_BASENAME}" \
    -output "artifact/onnxruntime-sim/onnxruntime"
cp -v "artifact/onnxruntime-sim/onnxruntime" \
    "Framework-sim/onnxruntime.framework/onnxruntime"

for arch in "${arches[@]}"; do
    echo "* Change ${arch} @rpath"
    # 自身への@rpathを変更
    install_name_tool -id "@rpath/onnxruntime.framework/onnxruntime" \
        "Framework-${arch}/onnxruntime.framework/onnxruntime"
done

echo "* Create XCFramework"
mkdir -p "artifact/${ONNXRUNTIME_BASENAME}"
xcodebuild -create-xcframework \
    -framework Framework-sim/onnxruntime.framework \
    -framework Framework-aarch64/onnxruntime.framework \
    -output "artifact/${ONNXRUNTIME_BASENAME}/onnxruntime.xcframework"

