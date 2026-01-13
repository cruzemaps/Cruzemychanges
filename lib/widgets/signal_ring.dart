import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignalRing extends StatelessWidget {
  final int recommendedSpeed;
  final String status; // "RED" or "GREEN"
  final double timeToGreen;

  const SignalRing({
    super.key,
    required this.recommendedSpeed,
    required this.status,
    required this.timeToGreen,
  });

  @override
  Widget build(BuildContext context) {
    Color ringColor = Colors.green;
    String advice = "MAINTAIN";

    if (status == "RED") {
      // If red, we want to slow down or coast to arrive when it turns green
      ringColor = Colors.blue; 
      advice = "COAST";
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor.withOpacity(0.6),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: ringColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
        gradient: RadialGradient(
          colors: [
            ringColor.withOpacity(0.2),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "$recommendedSpeed",
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            "MPH",
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            advice,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ringColor,
            ),
          ),
        ],
      ),
    );
  }
}
