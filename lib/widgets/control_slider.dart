import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final double? step;

  const ControlSlider({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.onChanged,
    this.min = 0.0,
    this.max = 100.0,
    this.step,
  });

  @override
  Widget build(BuildContext context) {
    // Calcula o número de divisões para as marcas visuais do slider.
    final int? divisions = (step != null && step! > 0)
        ? ((max - min) / step!).round()
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label - ${value.toInt()}%',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.grey.withAlpha(200),
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: color,
          inactiveColor: color.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
