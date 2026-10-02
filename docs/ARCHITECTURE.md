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

### Surface Coverage 3D

The scanner samples vertices from ARKit mesh anchors and quantizes them into world-space surface voxels. SceneDepth points are back-projected into the same coordinate system and increment coverage/confidence for matching cells. A bounded subset of weak and strong cells is published to the UI and rendered directly in the AR world as red / yellow / green surface markers.

Coverage state is persisted with the project, restored on resume, and blended with project-specific movement, geometry, depth, and directional coverage metrics.

### Missing Viewpoint Coach

For Object projects, the coach derives the weakest directional sector around the locked ROI and compares it with the current camera position to recommend a horizontal move plus high / level / low camera placement.

For non-object projects, the coach selects a weak mesh-surface coverage cell and compares its world-space bearing and elevation with the camera pose to recommend the next viewpoint.

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

Workflow continuation preserves project ID, stage progression, metrics, measurements, object ROI, sampled surface-coverage state, point-cloud artifacts, and captured source sessions. An `ARWorldMap` is archived on project save and supplied as the next AR session's `initialWorldMap`, allowing ARKit to attempt physical relocalization in the previously scanned space.

### Source-data persistence

When Source Archive is enabled for a normal scan, LiDARForge records sampled RGB JPEG frames, Float32 SceneDepth, UInt8 confidence maps, camera transforms, camera intrinsics, timestamps, and CoreMotion device-motion samples under the project `sources/` directory. Video projects use the same recorder as a standalone RGB-D dataset workflow. These source files are intentionally retained so future reconstruction algorithms can reprocess a project without requiring a new scan.

### Tool customization

`WorkspaceTool` preferences are stored in `AppState`. Capture functions and sensor tools can be enabled/disabled and reordered independently. Scanner quick controls and sensor-mode choices consume the same preferences, keeping the layout consistent across sessions.

## Privacy

No cloud backend is required by the architecture. Export and sharing are explicit user actions.
