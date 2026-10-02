# LiDARForge Architecture

## Design goals

- Local-first sensor processing.
- One capture engine shared by every project type.
- Project-specific guidance rather than duplicated scanners.
- Preserve source data so future reconstruction algorithms can reprocess a project.
- Keep sensor visualization independent from export/reconstruction.

## Layers

### UI

SwiftUI views:

- Home
- Project selection
- Guided scanner
- Sensor tools
- Settings

### Capture engine

ARKit + RealityKit currently provide:

- camera tracking
- feature points
- scene depth
- smoothed scene depth
- confidence map
- mesh reconstruction
- plane detection

### Capture Coach

The 0.1 coach uses a lightweight coverage estimate derived from:

- unique camera orientation bins
- unique camera-position cells
- reconstructed mesh anchor count
- scan duration
- project-specific capture thresholds
- depth validity, center distance, motion speed, and tracking state for live guidance

This is deliberately called an **estimate**. A future milestone will replace it with a surface-aware visibility map tied to reconstructed geometry.

### Point-cloud pipeline

LiDARForge currently keeps two point sources:

1. **SceneDepth cloud** — sampled depth pixels are back-projected using scaled camera intrinsics and transformed into ARKit world coordinates. Medium/high confidence samples are preferred and world-space points are deduplicated in a small voxel grid.
2. **AR feature points** — retained as a sparse fallback when SceneDepth is unavailable.

PLY export prefers the SceneDepth cloud.

### Reconstruction modules

Planned independent modules:

- RoomPlan
- Object Capture
- point cloud
- mesh
- RGB-D
- building / multi-room alignment

### Project storage

0.1 saves JSON project snapshots under the app Documents directory.

The planned package is:

```
Project.lidarforge/
├── project.json
├── rgb/
├── depth/
├── confidence/
├── poses/
├── imu/
├── pointcloud/
├── mesh/
├── textures/
└── exports/
```

## Privacy

No cloud backend is required by the architecture. Export and sharing are explicit user actions.
