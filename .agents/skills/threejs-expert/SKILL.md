---
name: threejs-expert
description: คู่มือผู้เชี่ยวชาญ Three.js (อ้างอิง mrdoob/three.js r187+) สำหรับสร้าง 3D Viewer, Interactive 3D HUD, WebGL2/WebGPU (TSL), โหลดโมเดล GLTF/Draco/KTX2/Meshopt, จัดแสง HDRLoader, Post-Processing (OutputPass) และระบบคืนหน่วยความจำการ์ดจอ (Scene Disposal)
---

# Three.js Expert Skill (`mrdoob/three.js` Modern Standard `r187+`)

ใช้ทักษะนี้ทันทีเมื่อต้องสร้าง แก้ไข หรือตรวจสอบโค้ดที่เกี่ยวข้องกับ **Three.js, 3D Model Viewer, WebGL2, WebGPU (`three/webgpu`), Three.js Shading Language (`three/tsl`), React Three Fiber (`@react-three/fiber`), หรือ Interactive 3D UI / HUD**

---

## 1. กฎเหล็กป้องกันการใช้ API เก่าที่ถูกถอดออกจาก Three.js แล้ว (Modern API Mandate)

AI มักเขียนโค้ด Three.js พังเพราะติดจำ API รุ่นเก่า (`r120–r150`) ห้ามใช้สิ่งที่อยู่ในคอลัมน์ซ้ายโดยเด็ดขาด:

| ❌ ห้ามใช้ (Deprecated / ถอดออกแล้ว) | ✅ ต้องใช้แทนตามมาตรฐาน `mrdoob/three.js` (`r180–r187+`) |
| :--- | :--- |
| `import ... from 'three/examples/jsm/...'` | `import ... from 'three/addons/...'` |
| `RGBELoader` (`three/addons/loaders/RGBELoader.js`) | **`HDRLoader`** (`three/addons/loaders/HDRLoader.js`) หรือ **`UltraHDRLoader`** |
| `renderer.outputEncoding = THREE.sRGBEncoding` | `renderer.outputColorSpace = THREE.SRGBColorSpace` (ค่าเริ่มต้นในรุ่นใหม่) |
| `texture.encoding = THREE.sRGBEncoding` | `texture.colorSpace = THREE.SRGBColorSpace` (เฉพาะสี/Albedo เท่านั้น) |
| `renderer.physicallyCorrectLights = true` | ถอดออกแล้ว (ใช้ระบบแสงจริงเป็นค่าเริ่มต้นตั้งแต่ `r155+`) |
| `new THREE.BoxBufferGeometry()` | `new THREE.BoxGeometry()` (Geometry ทุกตัวเป็น BufferGeometry ทั้งหมดแล้ว) |
| `new THREE.Clock()` | **`new THREE.Timer()`** หรือ `performance.now()` (`THREE.Clock` ถูก Deprecated ใน `r187+`) |
| `THREE.PCFSoftShadowMap` | **`THREE.PCFShadowMap`** (`PCFSoftShadowMap` ถูกถอดออกใน `r187+`) |
| `requestAnimationFrame(animate)` ดิบๆ | `renderer.setAnimationLoop(animate)` (หยุดอัตโนมัติเมื่อพับแท็บ + รองรับ WebGPU/WebXR) |
| `EffectComposer` โดยไม่มี `OutputPass` ปิดท้าย | ต้องใส่ **`new OutputPass()`** ปิดท้าย Linear Pass เสมอ เพื่อให้ Tone Mapping และ sRGB ถูกต้อง |

---

## 2. โครงสร้างการ Import มาตรฐาน (Package Exports & Import Map)

### 2.1 โปรเจกต์ที่ใช้ Bundler (Vite / Next.js / Webpack)
```javascript
// WebGL2 มาตรฐาน
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { HDRLoader } from 'three/addons/loaders/HDRLoader.js';

// หรือกรณีใช้ WebGPU + TSL (มี WebGL2 Fallback อัตโนมัติ)
import * as THREE from 'three/webgpu';
import { fn, uniform, uv, vec3, color } from 'three/tsl';
```

### 2.2 โปรเจกต์ Single-File HTML (Zero-Install ผ่าน `<script type="importmap">`)
```html
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.187.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.187.0/examples/jsm/"
  }
}
</script>
```

---

## 3. แม่แบบมาตรฐานสำหรับ 3D Viewer ระดับ Production (Production Boilerplate)

### 3.1 การตั้งค่า Renderer, Color Management, Tone Mapping และ DPR Cap
```javascript
const renderer = new THREE.WebGLRenderer({
  antialias: true,
  powerPreference: 'high-performance',
  alpha: false,
});

// จำกัด PixelRatio ไม่เกิน 2 เสมอ เพื่อป้องกันมือถือและจอ 4K/Retina การ์ดจอค้าง
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(container.clientWidth, container.clientHeight);

// ระบบสีและ Tone Mapping มาตรฐาน r187+
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping; // หรือ THREE.NeutralToneMapping สำหรับสีสินค้าตรงปก
renderer.toneMappingExposure = 1.0;
container.appendChild(renderer.domElement);
```

### 3.2 การโหลดโมเดล 3D แบบครบวงจร (`GLTFLoader` + `DRACOLoader` + `KTX2Loader` + `MeshoptDecoder`)
โมเดล `.glb`/`.gltf` ในงานจริงมักถูกบีบอัดมา ต้องผูกตัวถอดรหัสให้ครบก่อนสั่ง `.loadAsync()`:
```javascript
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { KTX2Loader } from 'three/addons/loaders/KTX2Loader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';

const dracoLoader = new DRACOLoader().setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.7/');
const ktx2Loader = new KTX2Loader()
  .setTranscoderPath('https://cdn.jsdelivr.net/npm/three@0.187.0/examples/jsm/libs/basis/')
  .detectSupport(renderer);

const gltfLoader = new GLTFLoader()
  .setDRACOLoader(dracoLoader)
  .setKTX2Loader(ktx2Loader)
  .setMeshoptDecoder(MeshoptDecoder);
```

### 3.3 การจัดกล้องให้พอดีกับขนาดโมเดลอัตโนมัติ (Auto-Center & Fit Camera to BoundingBox)
เมื่อโหลดโมเดลที่ไม่รู้สเกลล่วงหน้า ห้ามเดาค่า `camera.position` คงที่ ให้คำนวณจาก `Box3`:
```javascript
function frameModelToCamera(object, camera, controls) {
  const box = new THREE.Box3().setFromObject(object);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());

  object.position.sub(center); // ย้ายจุดศูนย์กลางโมเดลมาที่ (0, 0, 0)
  const maxDim = Math.max(size.x, size.y, size.z) || 1;
  const fov = camera.fov * (Math.PI / 180);
  const cameraZ = Math.abs((maxDim / 2) / Math.tan(fov / 2)) * 1.6;

  camera.near = maxDim / 100;
  camera.far = maxDim * 100;
  camera.position.set(cameraZ * 0.7, cameraZ * 0.5, cameraZ);
  camera.updateProjectionMatrix();

  if (controls) {
    controls.target.set(0, 0, 0);
    controls.maxDistance = maxDim * 10;
    controls.update();
  }
}
```

### 3.4 การทำ Post-Processing (`EffectComposer` + `UnrealBloomPass` + `OutputPass`)
```javascript
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
composer.addPass(new UnrealBloomPass(
  new THREE.Vector2(container.clientWidth, container.clientHeight),
  0.6, // strength
  0.4, // radius
  0.85 // threshold
));
composer.addPass(new OutputPass()); // บังคับมีเสมอเพื่อแปลง Linear -> sRGB + Tone Mapping
```

### 3.5 การแปะป้ายข้อความ HTML คมชัดบนวัตถุ 3D (`CSS2DRenderer`)
ห้ามใช้ `TextGeometry` วาดป้าย UI เยอะๆ เพราะกินโพลีกอนสูงและอ่านยาก ให้ใช้ `CSS2DRenderer`:
```javascript
import { CSS2DRenderer, CSS2DObject } from 'three/addons/renderers/CSS2DRenderer.js';

const labelRenderer = new CSS2DRenderer();
labelRenderer.setSize(container.clientWidth, container.clientHeight);
labelRenderer.domElement.style.position = 'absolute';
labelRenderer.domElement.style.top = '0';
labelRenderer.domElement.style.left = '0';
labelRenderer.domElement.style.pointerEvents = 'none';
container.appendChild(labelRenderer.domElement);
```

---

## 4. กฎเหล็กการคืนหน่วยความจำการ์ดจอ (Mandatory GPU Disposal & Power Saving)

Three.js **ไม่คืนหน่วยความจำ WebGL/WebGPU อัตโนมัติ** เมื่อลบ Object ออกจาก Scene ทุกครั้งที่มีการสลับโมเดลหรือปิดหน้า 3D ต้องมีฟังก์ชัน `disposeScene()` เสมอ:

```javascript
function disposeViewer({ renderer, scene, controls, composer, dracoLoader, ktx2Loader }) {
  // 1. หยุด Animation Loop ทันที
  renderer.setAnimationLoop(null);

  // 2. กวาดล้าง Geometry, Material และ Texture ทุกตัวใน Scene
  scene.traverse((obj) => {
    if (obj.geometry) obj.geometry.dispose();
    if (obj.material) {
      const materials = Array.isArray(obj.material) ? obj.material : [obj.material];
      for (const mat of materials) {
        for (const val of Object.values(mat)) {
          if (val && typeof val.dispose === 'function') val.dispose();
        }
        mat.dispose();
      }
    }
  });

  // 3. ล้าง Environment, Post-Processing, Controls, Worker Pools และ Renderer
  scene.environment?.dispose?.();
  scene.background?.dispose?.();
  composer?.dispose?.();
  controls?.dispose?.();
  dracoLoader?.dispose?.();
  ktx2Loader?.dispose?.();
  renderer.dispose();
}
```

---

## 5. มาตรฐานกราฟิกและการจัดหน้าจอระดับ Studio (`Threejs-Awesome-Graphics` Standards)

เมื่อต้องสร้างฉาก 3D ที่ดูสมจริงระดับงานโปรดักชัน (ห้ามทำกราฟิกกล่องเหลี่ยมทื่อๆ สีแบนๆ หรือวางการ์ด UI ทับฉาก 3D จนรก):

### 5.1 กฎ "3D Canvas as the Hero" และ Achromatic Studio Shell
1. **พื้นที่ฉาก 3D ต้องเป็นพระเอก (75%–85% ของหน้าจอ):**
   - ห้ามวาง Sidebar ขนาดใหญ่ขนาบทั้งซ้ายและขวาพร้อมกันจนบีบฉาก 3D เหลือช่องแคบๆ ตรงกลาง
   - ใช้โครงสร้าง **Studio Viewport + Single Right Inspector (`280px–320px`) + Micro-Topbar (`52px`) + Floating Bottom Command Dock**
2. **Achromatic Dark Graphite Frame (`#0b0b0d` / `#0e0e11` / `#131317`):**
   - กรอบ UI รอบนอกใช้โทนสีเทาดำกราไฟต์ (`#0e0e11`, ขอบบาง `1px solid rgba(255,255,255,0.08)`, ตัวอักษรสีขาวนวล `#edeae3` / `#a5a29c`) เพื่อให้สายตาของผู้ใช้โฟกัสที่แสงและสีสันของฉาก 3D เป็นหลัก ไม่ถูกปุ่มสีรุ้งแย่งสายตา

### 5.2 Procedural Studio Softbox IBL + 3-Point Rig + Contact Blush
1. **No-Post Baseline:** ฉาก 3D ต้องดูมีมิติและอ่านค่าแสงเงาได้ชัดเจนตั้งแต่ก่อนเปิด Post-Processing
2. **Procedural Softbox Environment (`scene.environment`):**
   - สร้าง Equirectangular HDR `DataTexture` ที่มี Softbox 5 ทิศทาง (Key `[1, 0.98, 0.94]`, Cool Fill `[0.82, 0.9, 1]`, Warm Rim `[1, 0.86, 0.66]`, Low Rim, Ground Bounce) หรือใช้ `RoomEnvironment` เพื่อให้วัสดุไม้ โลหะ และกระจกมีแสงสะท้อน IBL สมจริง
3. **Analytic Contact Blush (เงาสัมผัสพื้นใต้โต๊ะ/วัตถุ):**
   - วางแผ่นเงา Radial Falloff บางๆ ที่ `groundY + 0.004` (`depthWrite: false`) ใต้วัตถุและโต๊ะทุกตัว เพื่อไม่ให้วัตถุดูลอยเคว้งเหนือพื้น

### 5.3 Calibrated `MeshPhysicalMaterial` & Beveled Geometry (`RoundedBoxGeometry`)
- **ห้ามใช้ขอบกล่องคมกริบ (`BoxGeometry` ดิบๆ) กับเฟอร์นิเจอร์หรืออุปกรณ์ที่มนุษย์สร้าง:** ต้องใช้ `RoundedBoxGeometry` (`three/addons/geometries/RoundedBoxGeometry.js`) เพื่อให้ขอบมนรับไฮไลต์แสง (Specular Fillet) เสมอ
- **ค่าวัสดุมาตรฐาน (`MeshPhysicalMaterial`):**
  - **ไม้ Walnut หรู (โต๊ะประธาน/หัวหน้า):** `roughness: 0.42, metalness: 0.04, clearcoat: 0.62, clearcoatRoughness: 0.28`
  - **ไม้ Nordic Oak (โต๊ะทำงานทั่วไป):** `roughness: 0.45, metalness: 0.02, clearcoat: 0.45, clearcoatRoughness: 0.32`
  - **ทองเหลืองปัดเงา (Antique Gold Brass):** `roughness: 0.24, metalness: 0.78, clearcoat: 0.24, clearcoatRoughness: 0.20`
  - **อะลูมิเนียม/เหล็กพ่นทราย (ขาโต๊ะ/ตัวเครื่อง):** `roughness: 0.34, metalness: 0.82, clearcoat: 0.18`
- **Frame-Rate-Independent Camera Rig:**
  - การเลื่อนกล้องไปยังจุดโฟกัส (`camera.position` และ `controls.target`) ต้องใช้สมการ Exponential Decay: `factor = 1.0 - Math.exp(-lambda * dt)` เพื่อความนุ่มนวลในทุกอัตราเฟรมเรต

