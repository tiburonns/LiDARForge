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

This is deliberately called an **estimate**. A future milestone will replace it with a surface-aware visibility map tied to reconstructed geometry.

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
