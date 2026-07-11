import 'dart:math' as math;
import 'package:flutter/material.dart';

class Point3D {
  final double x, y, z;
  const Point3D(this.x, this.y, this.z);

  Point3D rotateX(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Point3D(
      x,
      y * cosA - z * sinA,
      y * sinA + z * cosA,
    );
  }

  Point3D rotateY(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Point3D(
      x * cosA - z * sinA,
      y,
      x * sinA + z * cosA,
    );
  }

  double distanceTo(Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

class IntroScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const IntroScreen({super.key, required this.onFinish});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Point3D> _spherePoints;

  @override
  void initState() {
    super.initState();
    _spherePoints = _generateSpherePoints(24);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    _controller.forward().then((_) {
      widget.onFinish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Point3D> _generateSpherePoints(int count) {
    final List<Point3D> points = [];
    final double phi = math.pi * (3.0 - math.sqrt(5.0)); // golden angle
    for (int i = 0; i < count; i++) {
      final double y = 1 - (i / (count - 1)) * 2;
      final double radius = math.sqrt(1 - y * y);
      final double theta = phi * i;
      final double x = math.cos(theta) * radius;
      final double z = math.sin(theta) * radius;
      points.add(Point3D(x, y, z));
    }
    return points;
  }

  // Linear interpolation between lists of Point3D
  List<Point3D> _interpolateShapes(List<Point3D> from, List<Point3D> to, double progress) {
    final List<Point3D> result = [];
    for (int i = 0; i < from.length; i++) {
      final x = from[i].x + (to[i].x - from[i].x) * progress;
      final y = from[i].y + (to[i].y - from[i].y) * progress;
      final z = from[i].z + (to[i].z - from[i].z) * progress;
      result.add(Point3D(x, y, z));
    }
    return result;
  }

  List<Point3D> _getShapePoints(double t) {
    // Define coordinates for shapes (24 vertices total to make morphing seamless)
    // Point: all collapsed to 0
    final point = List.generate(24, (_) => const Point3D(0, 0, 0));

    // Line: split left & right
    final line = List.generate(24, (i) => Point3D(i < 12 ? -1.0 : 1.0, 0, 0));

    // Triangle: 3 vertices
    final triVertices = [
      const Point3D(0, 1.0, 0),
      Point3D(-math.cos(math.pi / 6), -math.sin(math.pi / 6), 0),
      Point3D(math.cos(math.pi / 6), -math.sin(math.pi / 6), 0),
    ];
    final triangle = List.generate(24, (i) => triVertices[i % 3]);

    // Tetrahedron: 4 vertices in 3D
    final tetraVertices = [
      const Point3D(1 / 1.732, 1 / 1.732, 1 / 1.732),
      const Point3D(-1 / 1.732, -1 / 1.732, 1 / 1.732),
      const Point3D(-1 / 1.732, 1 / 1.732, -1 / 1.732),
      const Point3D(1 / 1.732, -1 / 1.732, -1 / 1.732),
    ];
    final tetrahedron = List.generate(24, (i) => tetraVertices[i % 4]);

    // Cube: 8 vertices
    final cubeVertices = <Point3D>[];
    for (int x = -1; x <= 1; x += 2) {
      for (int y = -1; y <= 1; y += 2) {
        for (int z = -1; z <= 1; z += 2) {
          cubeVertices.add(Point3D(x / 1.732, y / 1.732, z / 1.732));
        }
      }
    }
    final cube = List.generate(24, (i) => cubeVertices[i % 8]);

    // Octahedron: 6 vertices
    final octaVertices = [
      const Point3D(1.0, 0, 0),
      const Point3D(-1.0, 0, 0),
      const Point3D(0, 1.0, 0),
      const Point3D(0, -1.0, 0),
      const Point3D(0, 0, 1.0),
      const Point3D(0, 0, -1.0),
    ];
    final octahedron = List.generate(24, (i) => octaVertices[i % 6]);

    // Sphere
    final sphere = _spherePoints;

    // Segment mappings
    if (t < 0.1) {
      return point;
    } else if (t < 0.25) {
      // Point -> Line
      final p = (t - 0.1) / 0.15;
      return _interpolateShapes(point, line, p);
    } else if (t < 0.4) {
      // Line -> Triangle
      final p = (t - 0.25) / 0.15;
      return _interpolateShapes(line, triangle, p);
    } else if (t < 0.55) {
      // Triangle -> Tetrahedron
      final p = (t - 0.4) / 0.15;
      return _interpolateShapes(triangle, tetrahedron, p);
    } else if (t < 0.7) {
      // Tetrahedron -> Cube
      final p = (t - 0.55) / 0.15;
      return _interpolateShapes(tetrahedron, cube, p);
    } else if (t < 0.85) {
      // Cube -> Octahedron
      final p = (t - 0.7) / 0.15;
      return _interpolateShapes(cube, octahedron, p);
    } else {
      // Octahedron -> Sphere
      final p = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
      return _interpolateShapes(octahedron, sphere, p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final points = _getShapePoints(t);

          // Phase-based rotation speed (only starts rotating at Tetrahedron phase)
          double rotY = 0;
          double rotX = 0;
          if (t >= 0.4) {
            rotY = (t - 0.4) * 4 * math.pi;
            rotX = (t - 0.4) * 2 * math.pi;
          }

          // Scale transition for final exit zoom
          double zoomScale = 1.0;
          double opacity = 1.0;
          if (t > 0.94) {
            final double zoomProgress = (t - 0.94) / 0.06;
            zoomScale = 1.0 + zoomProgress * 8.0; // expand sphere to fill screen
            opacity = (1.0 - zoomProgress).clamp(0.0, 1.0);
          }

          return Opacity(
            opacity: opacity,
            child: CustomPaint(
              painter: PolyhedronPainter(
                points: points,
                rotX: rotX,
                rotY: rotY,
                zoomScale: zoomScale,
                progress: t,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class PolyhedronPainter extends CustomPainter {
  final List<Point3D> points;
  final double rotX;
  final double rotY;
  final double zoomScale;
  final double progress;

  PolyhedronPainter({
    required this.points,
    required this.rotX,
    required this.rotY,
    required this.zoomScale,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final scale = math.min(width, height) * 0.3 * zoomScale;

    // 1. Process and Rotate/Project all points
    final List<Offset> projected = [];
    final List<Point3D> transformed = [];

    for (int i = 0; i < points.length; i++) {
      // Apply slow rotations
      Point3D p = points[i].rotateY(rotY).rotateX(rotX);
      transformed.add(p);

      // Project onto 2D screen with standard perspective projection
      const double fov = 3.0;
      const double distance = 3.5;
      final factor = scale * fov / (distance + p.z);
      projected.add(Offset(
        width / 2 + p.x * factor,
        height / 2 + p.y * factor,
      ));
    }

    // 2. Draw Lines (Proximity constellation lines)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Proximity threshold changes depending on shape size/morphing
    // Standard side length is around 1.15 to 1.63.
    // We connect points if their 3D distance is within a range.
    final double maxDist = progress < 0.4 ? 0.01 : (progress > 0.85 ? 0.65 : 1.7);
    final double minDist = progress < 0.25 ? -1.0 : 0.05; // allow overlapping lines during line phase

    for (int i = 0; i < transformed.length; i++) {
      for (int j = i + 1; j < transformed.length; j++) {
        final d = transformed[i].distanceTo(transformed[j]);
        if (d <= maxDist && d >= minDist) {
          // Fade line color based on depth Z (further lines are fainter)
          final avgZ = (transformed[i].z + transformed[j].z) / 2.0; // from -1.0 to 1.0
          final depthFactor = (1.0 - (avgZ + 1.0) / 2.0).clamp(0.1, 0.95);

          // Natural warm glowing colors (terracotta / golden yellow)
          linePaint.color = Color.lerp(
            const Color(0xFFE07A5F),
            const Color(0xFFF2CC8F),
            (avgZ + 1.0) / 2.0,
          )!.withOpacity(depthFactor * 0.85);

          canvas.drawLine(projected[i], projected[j], linePaint);
        }
      }
    }

    // 3. Draw Points
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < transformed.length; i++) {
      final p = transformed[i];
      final depthFactor = (1.0 - (p.z + 1.0) / 2.0).clamp(0.2, 1.0);

      // Outer glow
      dotPaint.color = const Color(0xFF1E5631).withOpacity(depthFactor * 0.4);
      canvas.drawCircle(projected[i], 7.0, dotPaint);

      // Core point
      dotPaint.color = Colors.white.withOpacity(depthFactor);
      canvas.drawCircle(projected[i], 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PolyhedronPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.zoomScale != zoomScale;
  }
}
