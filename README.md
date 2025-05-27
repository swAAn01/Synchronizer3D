# Synchronizer3D

Synchronizer3D serves as an alternative to MultiplayerSynchronizer for synchronizing position and rotation properties for a `Node3D`.

## Motivation
MultiplayerSynchronizer is an extremely useful node for prototyping, but it has a number of limitations. This addresses two such limitations in particular: being unable to use `MultiplayerPeer.TRANSFER_MODE_UNRELIABLE` for on-change updates, and being unable to interpolate/extrapolate between received updates.

## How it Works
Every update interval, the authority node will check `sync_node` for property changes. If changes exist, the authority will send an update to each other connected peer. Non-authority peers will interpolate/extrapolate between received updates if enabled.

## How to Use
To use Synchronizer3D simply add it as a child of the node you wish to synchronize properties for, and configure it in the inspector. You can specify which properties to synchronize, when the authority should send updates, and whether non-authority peers should interpolate and/or extrapolate between updates. Most of the functions in this class should not be touched with the exception of `force_update()`, which can be used by the authority to reliably force a node's current properties. This is particularly useful in situations like teleporting the `sync_node`.

## Limitations
The main limitation of this node comes from its greatest strength: synchronizing only position and rotation. This means Synchronizer3D lacks the flexiblity of MultiplayerSynchronizer, but this drawback comes with the benefits of interpolation and extrapolation, and bandwidth optimization. That being said, there are other limitations as well:
Synchronizer3D can only be used to synchronize position and rotation for a `Node3D` (and types that extend `Node3D`).
For non-authority peers, the `Node.physics_interpolation_mode` of `sync_node` should be set to `Node.PHYSICS_INTERPOLATION_MODE_OFF` when using Synchronizer3D's interpolation/extrapolation features. Using these together will almost certainly create unexpected bugs (or are they expected if I'm talking about them here?). That being said, there may be cases where you wish to change the authority of `sync_node`, and therefore change its `Node.physics_interpolation_mode`. While changing authority is supported, Synchronizer3D will not automatically change `Node.physics_interpolation_mode` following authority changes; this needs to be handled separately.
This node should only be added to the `SceneTree` once the `MultiplayerAPI` has a `MultiplayerPeer`.
