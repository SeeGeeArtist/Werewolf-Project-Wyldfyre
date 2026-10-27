"""Optional API/order check against a user's local B42 engine, never bundled.

Uses javap, without initializing game classes or requiring native libraries.
This complements fixtures; neither check proves rendered appearance.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

jar = sys.argv[1]
base = "zombie.core.skinnedmodel.advancedanimation.AnimatedModel$AnimatedModelInstanceRenderData"
world = "zombie.core.skinnedmodel.model.ModelInstanceRenderData"
instance = "zombie.core.skinnedmodel.model.ModelInstance"


def bytecode(name):
    return subprocess.check_output(
        [os.environ.get("JAVAP_GAME", "javap"), "-p", "-c", "-classpath", jar, name],
        text=True,
    )


def method(text, declaration):
    assert declaration in text, f"Engine API changed: {declaration}"
    body = text.split(declaration, 1)[1]
    return re.split(r"\n  (?:public|private|protected|static) ", body, maxsplit=1)[0]


signature = f"public void initModel({instance}, {base});"
native = bytecode(base)
init_model = method(native, signature)
assert "Method initMatrixPalette:()V" in init_model, "palette moved out of initModel"
assert init_model.index("Field modelInstance:") < init_model.index("Method initMatrixPalette:()V")
publish = method(native, f"public {base} init();")
assert "Method initMatrixPalette:()V" not in publish, "publisher now rebuilds palette; re-audit ordering"
world_init = method(bytecode(world), signature)
assert world_init.index("RenderData.initModel:") < world_init.index("Field model:")
assert world_init.index("RenderData.initModel:") < world_init.index("Field tex:")
patch = (Path(__file__).parents[1] / "src/wtagarou/visuals/WolfHarnessInitPatch.java").read_text()
assert f'className="{base}"' in patch
assert 'methodName="initModel"' in patch
assert '@Patch.Argument(0)' in patch
print("PASS: supplied engine initModel signature, palette timing, world model/texture cache order.")
model_name = "zombie.core.skinnedmodel.model.Model"
model = method(bytecode(model_name),
               f"public {model_name}(zombie.asset.AssetPath, zombie.asset.AssetManager, {model_name}$ModelAssetParams);")
mesh_load = model[:model.index("Method zombie/core/skinnedmodel/model/MeshAssetManager.load:")]
assert "Model$ModelAssetParams.meshName:" in mesh_load
assert mesh_load.rindex("Model$ModelAssetParams.meshName:") < mesh_load.rindex('Method zombie/asset/AssetPath."<init>"')
manager = bytecode("zombie.core.skinnedmodel.ModelManager")
carrier = method(manager, f"public {instance} addStaticForcedTex({instance}, java.lang.String, java.lang.String, java.lang.String, java.lang.String);")
assert "Method loadStaticModel:" in carrier
script_load = method(manager, f"public {model_name} getLoadedModel(java.lang.String);")
assert "ModelScript.isStatic:Z" in script_load and "ModelScript.animationsMesh:" in script_load
assert "Method loadModelInternal:" in script_load
print("PASS: supplied engine carrier loads static, script loader honors skinning, mesh AssetPath uses meshName.")
shader_name = "zombie.core.skinnedmodel.shader.Shader"
shader = bytecode(shader_name)
start = method(shader, f"public void startCharacter(zombie.core.skinnedmodel.model.ModelSlotRenderData, {world});")
assert start.index("Field isStatic:Z") < start.index("Method setTransformMatrix:")
assert start.index("Method setTransformMatrix:") < start.index("Method setMatrixPalette:")
assert "Field zombie/core/skinnedmodel/model/ModelInstanceRenderData.matrixPalette:" in start
draw = method(bytecode(model_name), f"private void DrawSolid(zombie.core.skinnedmodel.model.ModelSlotRenderData, {world});")
assert draw.index("Shader.startCharacter:") < draw.index("ModelSlotRenderData.finalScale:") < draw.index("Shader.setScale:")
print("PASS: supplied engine static transform vs skinned palette branch and DrawSolid FinalScale handoff.")
print("Static bytecode check only; no native game render.")
