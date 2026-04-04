import 'package:flutter/material.dart';

class ControlSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double>? onChanged;

  const ControlSlider({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("${value.toInt()}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(value: value, min: 0, max: 100, activeColor: color, inactiveColor: color.withValues(alpha: 0.1), onChanged: onChanged),
        ),
      ],
    );
  }
}
