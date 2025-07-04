import 'package:flutter/material.dart';

class PushUpIcon extends StatelessWidget {
  final AnimationController controller;
  
  const PushUpIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 2 * (0.5 - controller.value.abs())),
          child: const Icon(
            Icons.sports_gymnastics,
            size: 28,
            color: Color(0xFF00E5FF),
          ),
        );
      },
    );
  }
}

class PullUpIcon extends StatelessWidget {
  final AnimationController controller;
  
  const PullUpIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + 0.4 * controller.value,
          child: const Icon(
            Icons.fitness_center,
            size: 28,
            color: Color(0xFF1BFFFF),
          ),
        );
      },
    );
  }
}

class SquatIcon extends StatelessWidget {
  final AnimationController controller;
  
  const SquatIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 3 * (0.5 - controller.value.abs())),
          child: const Icon(
            Icons.airline_seat_legroom_reduced,
            size: 28,
            color: Color(0xFF00E5FF),
          ),
        );
      },
    );
  }
}

class BicepCurlIcon extends StatelessWidget {
  final AnimationController controller;
  
  const BicepCurlIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: 0.3 * controller.value,
          child: const Icon(
            Icons.sports_kabaddi,
            size: 28,
            color: Color(0xFF1BFFFF),
          ),
        );
      },
    );
  }
}

class TricepIcon extends StatelessWidget {
  final AnimationController controller;
  
  const TricepIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -2 * (0.5 - controller.value.abs())),
          child: const Icon(
            Icons.fitness_center,
            size: 28,
            color: Color(0xFF00E5FF),
          ),
        );
      },
    );
  }
}

class LatPulldownIcon extends StatelessWidget {
  final AnimationController controller;
  
  const LatPulldownIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 4 * controller.value - 2),
          child: const Icon(
            Icons.sports_gymnastics,
            size: 28,
            color: Color(0xFF1BFFFF),
          ),
        );
      },
    );
  }
}

class BenchPressIcon extends StatelessWidget {
  final AnimationController controller;
  
  const BenchPressIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -3 * controller.value + 1.5),
          child: Transform.rotate(
            angle: 0.1 * controller.value,
            child: const Icon(
              Icons.fitness_center,
              size: 28,
              color: Color(0xFF1BFFFF),
            ),
          ),
        );
      },
    );
  }
}

class DeadliftIcon extends StatelessWidget {
  final AnimationController controller;
  
  const DeadliftIcon({super.key, required this.controller});



  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + 0.2 * controller.value,
          child: const Icon(
            Icons.sports_mma,
            size: 28,
            color: Color(0xFF00E5FF),
          ),
        );
      },
    );
  }
}