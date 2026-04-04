import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DataTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DataTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.orbitron(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
