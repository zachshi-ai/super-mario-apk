#!/bin/bash
set -e
SDK=/opt/android-sdk
BT=$SDK/build-tools/34.0.0
PLATFORM=$SDK/platforms/android-34/android.jar
OUT=build
rm -rf $OUT build.apk release
mkdir -p $OUT/gen $OUT/classes $OUT/dex

echo "[1/6] 编译资源"
$BT/aapt2 compile --dir res -o $OUT/res.zip

echo "[2/6] 链接资源与清单"
$BT/aapt2 link -o $OUT/app-unsigned.apk \
  -I $PLATFORM \
  --manifest AndroidManifest.xml \
  -R $OUT/res.zip \
  --java $OUT/gen \
  --min-sdk-version 24 --target-sdk-version 34 \
  --auto-add-overlay

echo "[3/6] 编译 Java"
javac --release 11 -encoding UTF-8 -classpath $PLATFORM -d $OUT/classes \
  src/com/stepx/mario/MainActivity.java $OUT/gen/com/stepx/mario/R.java 2>&1 | grep -v "bootstrap class path" || true

echo "[4/6] 转 dex"
$BT/d8 --lib $PLATFORM --min-api 24 --output $OUT/dex $OUT/classes/com/stepx/mario/*.class

echo "[5/6] 打包 dex 与 assets"
cp $OUT/app-unsigned.apk $OUT/app-with-dex.apk
(cd $OUT/dex && zip -q ../app-with-dex.apk classes.dex)
zip -qr $OUT/app-with-dex.apk assets
$BT/zipalign -f -p 4 $OUT/app-with-dex.apk $OUT/aligned.apk

echo "[6/6] 签名"
if [ ! -f keystore.jks ]; then
  keytool -genkeypair -v -keystore keystore.jks -alias mario -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass mariopass -keypass mariopass \
    -dname "CN=Super Mario, OU=Games, O=StepX, L=Shenzhen, S=Guangdong, C=CN" >/dev/null 2>&1
fi
$BT/apksigner sign --ks keystore.jks --ks-pass pass:mariopass --key-pass pass:mariopass \
  --ks-key-alias mario --out ../super-mario.apk $OUT/aligned.apk

$BT/apksigner verify --print-certs ../super-mario.apk | head -3
ls -lh ../super-mario.apk
