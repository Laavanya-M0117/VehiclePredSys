import 'package:flutter/material.dart';

class VehicleSpeedAnimation extends StatefulWidget {
  final double speed;
  final bool isMotorcycle;

  const VehicleSpeedAnimation({
    super.key,
    required this.speed,
    this.isMotorcycle = false,
  });

  @override
  State<VehicleSpeedAnimation> createState() => _VehicleSpeedAnimationState();
}

class _VehicleSpeedAnimationState extends State<VehicleSpeedAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double spd = widget.speed;

    // Color tiers: Green (0-45 km/h), Yellow (46-80 km/h), Red (>80 km/h)
    Color speedColor;
    String speedTierLabel;
    String speedTierShort;
    if (spd > 80.0) {
      speedColor = const Color(0xFFFF7675);
      speedTierLabel = 'OVERSPEED';
      speedTierShort = '> 80 km/h';
    } else if (spd > 45.0) {
      speedColor = const Color(0xFFFDCB6E);
      speedTierLabel = 'CRUISING';
      speedTierShort = '46–80 km/h';
    } else {
      speedColor = const Color(0xFF00B894);
      speedTierLabel = 'CITY PACE';
      speedTierShort = '0–45 km/h';
    }

    final double maxScale = widget.isMotorcycle ? 160.0 : 200.0;
    final double progress = (spd / maxScale).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: speedColor.withValues(alpha: spd > 80 ? 0.9 : 0.4),
              width: spd > 80 ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: speedColor.withValues(alpha: spd > 80 ? 0.22 : 0.07),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Row: Speed number + badge + vehicle icon ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Speed number
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        spd.toStringAsFixed(1),
                        style: TextStyle(
                          color: speedColor,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'KM/H',
                        style: TextStyle(
                          color: speedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Tier badge + icon (kept compact)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: speedColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: speedColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          speedTierLabel,
                          style: TextStyle(
                            color: speedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: speedColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isMotorcycle
                              ? Icons.two_wheeler_rounded
                              : Icons.directions_car_filled_rounded,
                          color: speedColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Animated Speed Progress Bar ──
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final barWidth = constraints.maxWidth;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      width: barWidth,
                      child: Stack(
                        children: [
                          Container(color: const Color(0xFF0D0E15)),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00B894),
                                    if (progress > 0.3) const Color(0xFFFDCB6E),
                                    if (progress > 0.6) const Color(0xFFFF7675),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Animated kinetic particle flash
                          Positioned(
                            left: (barWidth - 14) * progress * _ctrl.value,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // ── Bottom legend (compact, won't overflow) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Speed zone dots – compact
                  Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    children: const [
                      _ZoneDot(color: Color(0xFF00B894), label: '0-45'),
                      _ZoneDot(color: Color(0xFFFDCB6E), label: '46-80'),
                      _ZoneDot(color: Color(0xFFFF7675), label: '>80'),
                    ],
                  ),
                  Text(
                    'Max ${maxScale.toInt()} km/h',
                    style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoneDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ZoneDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 7),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 9)),
      ],
    );
  }
}
