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
- RoomPlan interior and multi-room building capture
- Object Capture appearance workflow
- RGB-D recorder
- Project detail / continuation
- Scan Health report

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

For Object projects, the coach can lock a world-space target from an AR raycast. SceneDepth points outside the selected ROI radius are filtered from the dense object cloud. The app also maintains a 3 × 8 directional coverage grid around the locked target to show missing, partial, and well-observed sectors.

The global coverage score is still deliberately called an **estimate**. The directional grid is useful guidance, but it is not yet the final mesh-projected visibility heatmap planned for Coverage Coach 2.

### Point-cloud pipeline

LiDARForge currently keeps two point sources:

1. **SceneDepth cloud** — sampled depth pixels are back-projected using scaled camera intrinsics and transformed into ARKit world coordinates. Medium/high confidence samples are preferred and world-space points are deduplicated in a small voxel grid.
2. **AR feature points** — retained as a sparse fallback when SceneDepth is unavailable.

PLY export prefers the SceneDepth cloud.

### Interior / RoomPlan pipeline

Interior projects start with Apple's RoomPlan capture UI for the Structure pass. The processed CapturedRoom result is summarized into walls, doors, windows, openings, floors, and detected objects, then exported locally as a USDZ mesh. The workflow can continue directly into LiDARForge's Detail pass.

### Performance profiles

Fast, Balanced, and Maximum modes adjust SceneDepth sampling stride, dense-cloud sampling interval, and preview refresh rate. They are persisted in AppState and shared by project scans and sensor tools.

### Reconstruction modules

Independent modules:

- **RoomPlan** — single-room Structure capture, structural summary, 2D plan preview, and USDZ mesh export.
- **Building RoomPlan** — repeated room capture sharing one AR session, then StructureBuilder merge.
- **Object Capture** — object detection and guided Appearance capture with multi-pass / flip workflow and point-cloud review.
- **Point cloud** — SceneDepth back-projection plus AR feature-point fallback.
- **RGB-D** — synchronized RGB JPEG, Float32 depth, confidence, camera transform, intrinsics, and timestamps.
- **Mesh** — ARKit scene reconstruction is live; generalized mesh export/conversion remains planned.

### Project storage

Projects are stored under the app Documents directory. Each project keeps `project.json` and can persist its preferred point-cloud artifact. The Projects UI can reopen the workflow while preserving project identity and measurements.

A shareable `.lidarforge` directory package is built from the current project files plus a manifest. RGB-D recording also uses a `.lidarforge` dataset directory with synchronized source data.

Current / target package layout:

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

### Continuation and relocalization

Workflow continuation is implemented at the project level: project ID, stage progression, metrics, measurements, and stored artifacts remain available when reopening. True spatial relocalization across a later app session still requires persisting and restoring an `ARWorldMap`; this remains the next continuity milestone.

## Privacy

No cloud backend is required by the architecture. Export and sharing are explicit user actions.
