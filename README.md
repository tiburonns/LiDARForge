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
- **3D Video / RGB-D** — synchronized color + depth capture (planned).

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

## Current milestone — 0.1 Foundation

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
- RoomPlan room summary and USDZ mesh export
- Dense SceneDepth PLY export and sharing
- Pause/resume and interruption recovery without intentionally discarding the current scan
- Sensor tools screen
- CI build workflow

> LiDAR features must be tested on a physical supported device. Simulator can build the UI, but it cannot provide LiDAR sensor data.

## Planned next milestones

- Room completeness coaching and 2D floor-plan preview
- Object Capture guided photogrammetry
- Surface-aware coverage heatmap
- RGB-D recording
- Multi-room building projects
- Mesh export
- USDZ / OBJ / GLB export pipeline
- Raw frame dataset export
- Project package format (`.lidarforge`)

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
