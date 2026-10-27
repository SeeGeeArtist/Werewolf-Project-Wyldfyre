#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ZB="${ZB_JAR:-$HERE/../../ZombieBuddy/libs/ZombieBuddy.jar}"
JAR="$HERE/../42/media/java/client/WTAGarouVisuals.jar"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mapfile -t TESTS < <(find "$HERE/test" "$HERE/stubs" -name '*.java' | sort)
javac --release 17 -cp "$ZB:$JAR" -d "$BUILD" "${TESTS[@]}"
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" ScaleTest
java -ea -Djdk.attach.allowAttachSelf=true -Dwtagarou.test.root="$HERE/.." -cp "$ZB:$JAR:$BUILD" WolfCombatTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" WolfHarnessTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" WolfHarnessLoadTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" WolfHarnessScaleTest
java -ea -Dwtagarou.test.root="$HERE/.." -cp "$ZB:$JAR:$BUILD" WolfClipLoaderTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" WolfPlayerClipsTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" AnimatorRestoreTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" WolfSeatedLookTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" StabilityTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" StealthTest
java -ea -cp "$ZB:$JAR:$BUILD" CrinosAttackDiagnosticsTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" TraitsTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" StrideTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" ClimbTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" CoatableTagTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" NitrateHeatTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" BulkFormTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" SilverBurnTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" CrinosCosmeticsTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" CrinosFaceVisualsTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" CrinosHeadCullTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" SilverHitTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" TrueFormCorpseTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" DebugConsoleTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" FurTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" DoorwayTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" PoiseTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" ToughnessTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" CrinosSwingTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" HowlMaskTest
java -ea -Djdk.attach.allowAttachSelf=true -cp "$ZB:$JAR:$BUILD" CrowdChargeTest
if [[ -n "${JOML_JAR:-}" ]]; then
    # External test-only dependency, not bundled in the mod or game fixtures.
    mapfile -t MATRIX_TESTS < <(find "$HERE/matrix-test" -name '*.java' | sort)
    javac --release 17 -cp "$ZB:$JAR:$BUILD:$JOML_JAR" -d "$BUILD/matrix" "${MATRIX_TESTS[@]}"
    java -ea -Djdk.attach.allowAttachSelf=true \
        -cp "$BUILD/matrix:$ZB:$JAR:$BUILD:$JOML_JAR" CrinosHeadwearMatrixTest
fi
if [[ -n "${PZ_JAR:-}" ]]; then
    python3 "$HERE/test/engine_harness_contract.py" "$PZ_JAR"
    python3 "$HERE/test/engine_playtest_contract.py" "$PZ_JAR"
    "${JAVA_GAME:-java}" -ea -Djdk.attach.allowAttachSelf=true \
        -cp "$ZB:$JAR:$BUILD" EngineHarnessAdviceTest "$PZ_JAR"
    "${JAVA_GAME:-java}" -ea -Djdk.attach.allowAttachSelf=true \
        -cp "$ZB:$JAR:$BUILD" EnginePlaytestAdviceTest "$PZ_JAR"
    # Compile/run separately against actual asset classes, not test stubs.
    "${JAVAC_GAME:-javac}" --release 17 -cp "$PZ_JAR" -d "$BUILD/native" \
        "$HERE/native-test/EngineAssetCacheTest.java"
    "${JAVA_GAME:-java}" -ea -cp "$BUILD/native:$PZ_JAR" EngineAssetCacheTest
    # Optional private local check: never download or bundle the game JAR.
    # Fixtures precede the game so this exercises real matrix/property math,
    # not a native game boot. JAVA_GAME must support the uploaded game build.
    "${JAVA_GAME:-java}" -ea -Djdk.attach.allowAttachSelf=true \
        -cp "$ZB:$JAR:$BUILD:$PZ_JAR" AttachmentMatrixTest
fi
