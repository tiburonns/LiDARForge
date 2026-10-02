# LiDARForge Roadmap

## 0.1 — Foundation

- [x] SwiftUI app shell
- [x] English / Spanish / System language
- [x] Object / Interior / Exterior / Building / Video project types
- [x] ARKit + RealityKit scanning session
- [x] Scene Depth
- [x] Smoothed Scene Depth
- [x] LiDAR mesh reconstruction
- [x] Feature points
- [x] Confidence map sampling and preview
- [x] Depth preview
- [x] Camera / points / mesh / depth / confidence / raw views
- [x] Three-pass guided workflow
- [x] First capture coverage estimate
- [x] Local project snapshot JSON
- [x] Saved-project library and deletion
- [x] Pause/resume without resetting the active AR session
- [x] AR interruption recovery hooks
- [x] Project-specific capture profiles
- [x] Distance-aware capture coaching from SceneDepth
- [x] Dense SceneDepth point-cloud accumulation
- [x] PLY point-cloud export with sparse AR fallback
- [x] Fast / Balanced / Maximum capture profiles
- [x] Scan Health report
- [x] Object target lock and ROI filtering
- [x] 24-sector object coverage map
- [x] CI build workflow

## 0.2 — Interior

- [x] RoomPlan integration
- [x] walls / openings / doors / windows summary
- [ ] room completeness coaching
- [ ] 2D plan preview
- [x] USDZ room mesh export

## 0.3 — Object

- [ ] ObjectCaptureSession integration
- [ ] guided orbit capture
- [ ] low / normal / high angle pass guidance
- [ ] ObjectCapture point cloud preview
- [ ] local photogrammetry reconstruction when supported

## 0.4 — Coverage Coach 2

- [x] directional object coverage heatmap
- [ ] mesh-projected surface-aware coverage heatmap
- [ ] missing-viewpoint detection
- [ ] occlusion detection
- [ ] depth-confidence heatmap projected into the mesh
- [ ] motion-blur / exposure warnings

## 0.5 — RGB-D / Raw

- [ ] synchronized RGB + depth recording
- [ ] camera pose stream
- [ ] camera intrinsics
- [ ] IMU stream
- [ ] frame timestamps
- [ ] dataset export

## 0.6 — Building

- [ ] multi-room projects
- [ ] room alignment
- [ ] floor hierarchy
- [ ] exterior + interior project combination

## 0.7 — Export

- [x] PLY point cloud
- [ ] XYZ
- [ ] LAS
- [ ] USDZ
- [ ] OBJ
- [ ] STL
- [ ] GLB
- [ ] PDF / SVG / DXF plan exports

## 1.0

- [ ] production QA on physical LiDAR devices
- [ ] accessibility audit
- [ ] performance / thermal tuning
- [ ] long-session recovery
- [ ] interruption / relocalization recovery
- [ ] export validation
- [ ] TestFlight readiness
