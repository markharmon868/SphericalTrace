# SphericalTrace

A ray marching and sphere tracing implementation for terrain rendering.

This project was my winning solo project submission to the Huawei Challenge #1: Interactive Landscape Graphics at SFU's 2025 Stormhacks hackathon.

## Overview

This project was started with the challenge template in `ray_marching_terrain_template/` provided by the Huawei team, and further developed by me during the 2 day hackathon.

This project improves upon the provided ray marching techniques for rendering 3D height maps by using:
- **Sphere Tracing**: Adaptive step size for optimized performance using an approximated SDF
- **K-Lipschitz bound based Signed Distance Function**: The K-Lipschitz upper bound on maximum slope in terrain is calculated from the provided Fractional Brownian Motion function for the height map caluclation
- **Optimized Terrain Generation**: The height map level of detail is dependent upon the camera distance from the mesh.
- **Illinois Method**: The Illinois method for root finding is used to reduce the number of small steps when the ray is close to the mesh surface

## Files

- `sphereTraceAlgorithm/` - GLSL shader templates
  - `sphere_traced_ray_march.glsl` - Main shader implementation
  - `include/support_functions.glsl` - Utility functions and terrain generation
- `calculate_raymarching_steps.py` - Python script for performance analysis
- `image_compare.py` - Image comparison utilities
- `BasselineRaymarchedImages/` - Original algorithm renders
- `SphereTracedImages/` - My optimized algorithm renders


## Features

### Terrain Generation
- Perlin noise based height maps
- Fractal Brownian Motion (FBM) for realistic terrain
- Distance-based level of detail optimization

### Ray Marching Algorithms
- **Sphere Tracing**: Adaptive stepping with maximum terrain slope bounded by K-Lipschitz
- **Early Termination**: Plane intersection for performance optimization
- **Illinois Root Calculation**: Hit detection is optimized with the Illinois method

### Performance Results
- Total step count reduced by 37.8%
- FPS increase on my machine from 10 to 17 FPS
- Memory usage decrease from 7.5 to 6 MB
- Time to render each frame decrease from 100MS to 60MS

## Usage

1. Load the GLSL shaders in your graphics application
2. Adjust terrain parameters in `support_functions.glsl`
3. Run `calculate_raymarching_steps.py` for performance analysis
