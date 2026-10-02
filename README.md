# LiDARForge

LiDARForge is a local-first iOS spatial capture workspace for LiDAR-equipped iPhone and iPad devices.

Instead of exposing a single generic scan button, LiDARForge organizes capture by **project intent** and guides the user through three passes:

1. **Structure** — establish geometry, boundaries, scale, and tracking.
2. **Detail** — revisit incomplete viewpoints and low-confidence areas.
3. **Appearance** — capture the visual information needed for textures and photogrammetry.

## Project types

- **Object** — small and medium physical objects.
- **Interior** — rooms and indoor spaces.
- **Exterior** — outdoor areas, facades, vehicles, and structures.
- **Building** — multi-room / multi-zone architectural capture.
- **3D Video / RGB-D** — synchronized RGB, depth, confidence, pose, intrinsics, and timestamps.

## Sensor tools

The first implementation includes a live AR/LiDAR workspace with:

- Camera
- Camera + feature points
- LiDAR mesh
- Depth preview
- Confidence preview
- Raw sensor metrics
- Night-vision-style depth visualization
- Capture coverage estimate
- Project-aware speed and distance guidance
- Tap-to-lock object ROI with background filtering
- 24-sector directional coverage map for object capture
- Scan Health report with actionable quality checks
- Fast / Balanced / Maximum capture quality modes
- Dense SceneDepth point-cloud accumulation with sparse AR fallback
- Tracking and mesh statistics

## Current milestone — 0.2 Capture Intelligence

The repository contains an Xcode iOS application targeting iOS 17+ with:

- SwiftUI application shell
- English / Spanish / System language selection
- Project-type picker
- Guided Structure → Detail → Appearance workflow
- ARKit + RealityKit LiDAR session
- Scene-depth and smoothed-depth support when available
- Mesh reconstruction when available
- Live feature-point / mesh / tracking metrics
- Live depth and confidence-map previews
- Project snapshot persistence as JSON
- Saved-project library with delete support
- RoomPlan structural capture for Interior projects
- RoomPlan room summary, structural completeness, 2D plan preview, and USDZ mesh export
- Multi-room RoomPlan building capture with StructureBuilder merge
- Dense SceneDepth PLY export and sharing
- RealityKit ObjectCaptureSession appearance workflow with object detection, guided passes, point-cloud preview, flip/new-pass flow, and capture sharing
- RGB-D dataset recording into local `.lidarforge` datasets
- Persistent project point-cloud artifacts and shareable `.lidarforge` project packages
- Project detail screen with workflow progress and continuation
- Pause/resume and interruption recovery without intentionally discarding the current scan
- Sensor tools screen
- CI build workflow

> LiDAR features must be tested on a physical supported device. Simulator can build the UI, but it cannot provide LiDAR sensor data.

## Planned next milestones

- Mesh-projected surface-aware coverage heatmap
- Missing-viewpoint and occlusion detection
- Depth-confidence heatmap projected into reconstructed geometry
- Persisted ARWorldMap / relocalization data for true later-session scan continuation
- IMU stream inside RGB-D datasets
- Mesh export and conversion
- OBJ / STL / GLB / XYZ / LAS export pipeline
- PDF / SVG / DXF architectural plan export
- Physical-device QA, performance tuning, accessibility, and TestFlight hardening

See [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Privacy

The architecture is **local-first**. Sensor frames and project data remain on-device unless the user explicitly exports or shares them.

## Languages

- English
- Español
- System language

Spanish documentation: [README.es.md](README.es.md)

## License

MIT — see [LICENSE](LICENSE).
