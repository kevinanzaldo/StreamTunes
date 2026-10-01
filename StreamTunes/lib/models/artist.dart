import 'package:flutter/material.dart';

class Artist {
  final String id;
  final String name;
  final String genre;
  final String bio;
  final int monthlyListeners;
  final List<Color> avatarGradient;
  final IconData avatarIcon;
  final double donationGoal;
  double donationsCollected;
  final String location;
  final Map<String, String> socialLinks;
  final int yesterdayPlays;

  Artist({
    required this.id,
    required this.name,
    required this.genre,
    required this.bio,
    required this.monthlyListeners,
    required this.avatarGradient,
    required this.avatarIcon,
    this.donationGoal = 50000.0,
    this.donationsCollected = 12500.0,
    required this.location,
    this.socialLinks = const {
      'Instagram': '@bandaunder',
      'Bandcamp': 'bandaunder.bandcamp.com',
      'YouTube': 'youtube.com/@bandaunder',
    },
    this.yesterdayPlays = 142,
  });

  String get formattedListeners {
    if (monthlyListeners >= 1000000) {
      return '${(monthlyListeners / 1000000).toStringAsFixed(1)}M oyentes mensuales';
    } else if (monthlyListeners >= 1000) {
      return '${(monthlyListeners / 1000).toStringAsFixed(1)}K oyentes mensuales';
    }
    return '$monthlyListeners oyentes mensuales';
  }

  double get donationProgress {
    if (donationGoal <= 0) return 1.0;
    return (donationsCollected / donationGoal).clamp(0.0, 1.0);
  }
}
