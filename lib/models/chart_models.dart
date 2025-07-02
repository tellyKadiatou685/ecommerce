// lib/models/chart_models.dart - MODÈLES SPÉCIALISÉS POUR LES GRAPHIQUES

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'merchant_stats_model.dart';

/// Configuration du style et du comportement du graphique
class ChartConfig {
  final Color primaryColor;
  final Color gradientStartColor;
  final Color gradientEndColor;
  final Color gridColor;
  final Color labelColor;
  final Color backgroundColor;
  final double strokeWidth;
  final double pointRadius;
  final double animationDuration;
  final EdgeInsets padding;
  final bool showGrid;
  final bool showLabels;
  final bool showPoints;
  final bool showGradient;
  final bool enableAnimation;

  const ChartConfig({
    this.primaryColor = const Color(0xFF3B82F6),
    this.gradientStartColor = const Color(0xFF3B82F6),
    this.gradientEndColor = const Color(0xFF60A5FA),
    this.gridColor = const Color(0xFFE5E7EB),
    this.labelColor = const Color(0xFF6B7280),
    this.backgroundColor = Colors.white,
    this.strokeWidth = 3.0,
    this.pointRadius = 6.0,
    this.animationDuration = 1500.0,
    this.padding = const EdgeInsets.all(20),
    this.showGrid = true,
    this.showLabels = true,
    this.showPoints = true,
    this.showGradient = true,
    this.enableAnimation = true,
  });

  /// Configuration par défaut pour les revenus
  static const ChartConfig revenue = ChartConfig(
    primaryColor: Color(0xFF10B981),
    gradientStartColor: Color(0xFF10B981),
    gradientEndColor: Color(0xFF34D399),
  );

  /// Configuration pour les commandes
  static const ChartConfig orders = ChartConfig(
    primaryColor: Color(0xFF3B82F6),
    gradientStartColor: Color(0xFF3B82F6),
    gradientEndColor: Color(0xFF60A5FA),
  );

  /// Configuration mode sombre
  static const ChartConfig dark = ChartConfig(
    primaryColor: Color(0xFF60A5FA),
    gradientStartColor: Color(0xFF60A5FA),
    gradientEndColor: Color(0xFF93C5FD),
    gridColor: Color(0xFF374151),
    labelColor: Color(0xFF9CA3AF),
    backgroundColor: Color(0xFF111827),
  );

  /// Créer une copie avec des modifications
  ChartConfig copyWith({
    Color? primaryColor,
    Color? gradientStartColor,
    Color? gradientEndColor,
    Color? gridColor,
    Color? labelColor,
    Color? backgroundColor,
    double? strokeWidth,
    double? pointRadius,
    double? animationDuration,
    EdgeInsets? padding,
    bool? showGrid,
    bool? showLabels,
    bool? showPoints,
    bool? showGradient,
    bool? enableAnimation,
  }) {
    return ChartConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      gradientStartColor: gradientStartColor ?? this.gradientStartColor,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      gridColor: gridColor ?? this.gridColor,
      labelColor: labelColor ?? this.labelColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      pointRadius: pointRadius ?? this.pointRadius,
      animationDuration: animationDuration ?? this.animationDuration,
      padding: padding ?? this.padding,
      showGrid: showGrid ?? this.showGrid,
      showLabels: showLabels ?? this.showLabels,
      showPoints: showPoints ?? this.showPoints,
      showGradient: showGradient ?? this.showGradient,
      enableAnimation: enableAnimation ?? this.enableAnimation,
    );
  }
}

/// Point de données pour le graphique avec coordonnées calculées
class ChartPoint {
  final double x;
  final double y;
  final double value;
  final DateTime date;
  final String label;
  final Map<String, dynamic> metadata;

  const ChartPoint({
    required this.x,
    required this.y,
    required this.value,
    required this.date,
    required this.label,
    this.metadata = const {},
  });

  /// Créer un point à partir de RevenueChartData
  factory ChartPoint.fromRevenueData(
    RevenueChartData data,
    double x,
    double y,
  ) {
    return ChartPoint(
      x: x,
      y: y,
      value: data.revenue,
      date: data.date,
      label: data.dayOfWeek,
      metadata: {
        'revenue': data.revenue,
        'orderCount': data.orderCount,
        'formattedRevenue': data.formattedRevenue,
        'shortRevenue': data.shortRevenue,
        'averageOrderValue': data.averageOrderValue,
      },
    );
  }

  /// Offset pour le dessin
  Offset get offset => Offset(x, y);

  /// Créer une copie avec de nouvelles coordonnées
  ChartPoint copyWith({
    double? x,
    double? y,
    double? value,
    DateTime? date,
    String? label,
    Map<String, dynamic>? metadata,
  }) {
    return ChartPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      value: value ?? this.value,
      date: date ?? this.date,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ChartPoint(x: $x, y: $y, value: $value, label: $label)';
  }
}

/// Données du graphique avec calculs et utilitaires
class ChartData {
  final List<RevenueChartData> rawData;
  final List<ChartPoint> points;
  final double minValue;
  final double maxValue;
  final double valueRange;
  final ChartConfig config;
  final Size chartSize;

  ChartData({
    required this.rawData,
    required this.points,
    required this.minValue,
    required this.maxValue,
    required this.valueRange,
    required this.config,
    required this.chartSize,
  });

  /// Créer ChartData à partir de RevenueChartData
  factory ChartData.fromRevenueData(
    List<RevenueChartData> data,
    Size size,
    ChartConfig config,
  ) {
    if (data.isEmpty) {
      return ChartData(
        rawData: [],
        points: [],
        minValue: 0,
        maxValue: 0,
        valueRange: 0,
        config: config,
        chartSize: size,
      );
    }

    // Calculer les valeurs min/max
    final values = data.map((d) => d.revenue).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;

    // Calculer les dimensions du graphique
    final chartWidth = size.width - config.padding.horizontal;
    final chartHeight = size.height - config.padding.vertical;

    // Calculer les points
    final points = <ChartPoint>[];
    final stepX = data.length > 1 ? chartWidth / (data.length - 1) : 0;

    for (int i = 0; i < data.length; i++) {
      final x = config.padding.left + stepX * i;
      
      double normalizedValue;
      if (range > 0) {
        normalizedValue = (data[i].revenue - minVal) / range;
      } else {
        normalizedValue = 0.5; // Centre si toutes les valeurs sont identiques
      }
      
      final y = config.padding.top + chartHeight - (normalizedValue * chartHeight);
      
      points.add(ChartPoint.fromRevenueData(data[i], x, y));
    }

    return ChartData(
      rawData: data,
      points: points,
      minValue: minVal,
      maxValue: maxVal,
      valueRange: range,
      config: config,
      chartSize: size,
    );
  }

  /// Obtenir les points animés
  List<ChartPoint> getAnimatedPoints(double animationValue) {
    return points.map((point) {
      final animatedX = config.padding.left + 
                      (point.x - config.padding.left) * animationValue;
      final animatedY = chartSize.height - config.padding.bottom - 
                       (chartSize.height - config.padding.bottom - point.y) * animationValue;
      
      return point.copyWith(x: animatedX, y: animatedY);
    }).toList();
  }

  /// Rectangle du graphique
  Rect get chartRect {
    return Rect.fromLTWH(
      config.padding.left,
      config.padding.top,
      chartSize.width - config.padding.horizontal,
      chartSize.height - config.padding.vertical,
    );
  }

  /// Labels de l'axe Y (revenus)
  List<ChartLabel> get yAxisLabels {
    final labels = <ChartLabel>[];
    const labelCount = 4;
    
    for (int i = 0; i <= labelCount; i++) {
      final value = (maxValue / labelCount) * i;
      final y = chartRect.bottom - (chartRect.height / labelCount) * i;
      
      String text;
      if (value >= 1000000) {
        text = '${(value / 1000000).toStringAsFixed(1)}M';
      } else if (value >= 1000) {
        text = '${(value / 1000).toStringAsFixed(1)}K';
      } else {
        text = value.toStringAsFixed(0);
      }
      
      labels.add(ChartLabel(
        text: text,
        position: Offset(chartRect.left - 8, y),
        value: value,
        alignment: Alignment.centerRight,
      ));
    }
    
    return labels;
  }

  /// Labels de l'axe X (dates)
  List<ChartLabel> get xAxisLabels {
    final labels = <ChartLabel>[];
    
    for (int i = 0; i < points.length; i++) {
      // Afficher 1 label sur 2 si trop de données
      if (i % 2 == 0 || points.length <= 5) {
        final point = points[i];
        labels.add(ChartLabel(
          text: point.label,
          position: Offset(point.x, chartRect.bottom + 8),
          value: i.toDouble(),
          alignment: Alignment.topCenter,
        ));
      }
    }
    
    return labels;
  }

  /// Trouver le point le plus proche d'une position
  ChartPoint? findNearestPoint(Offset position, {double maxDistance = 30}) {
    ChartPoint? nearest;
    double minDistance = double.infinity;
    
    for (final point in points) {
      final distance = (position - point.offset).distance;
      if (distance < minDistance && distance <= maxDistance) {
        minDistance = distance;
        nearest = point;
      }
    }
    
    return nearest;
  }

  /// Statistiques du graphique
  ChartStats get stats {
    if (rawData.isEmpty) {
      return ChartStats.empty();
    }
    
    final totalRevenue = rawData.fold(0.0, (sum, data) => sum + data.revenue);
    final totalOrders = rawData.fold(0, (sum, data) => sum + data.orderCount);
    final averageRevenue = totalRevenue / rawData.length;
    final bestDay = rawData.reduce((a, b) => a.revenue > b.revenue ? a : b);
    
    return ChartStats(
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      averageRevenue: averageRevenue,
      bestDay: bestDay,
      dataPoints: rawData.length,
    );
  }

  /// Vérifier si les données sont vides
  bool get isEmpty => rawData.isEmpty;

  /// Nombre de points
  int get length => points.length;
}

/// Label pour les axes du graphique
class ChartLabel {
  final String text;
  final Offset position;
  final double value;
  final Alignment alignment;
  final TextStyle? style;

  const ChartLabel({
    required this.text,
    required this.position,
    required this.value,
    this.alignment = Alignment.center,
    this.style,
  });
}

/// Statistiques calculées du graphique
class ChartStats {
  final double totalRevenue;
  final int totalOrders;
  final double averageRevenue;
  final RevenueChartData? bestDay;
  final int dataPoints;

  const ChartStats({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageRevenue,
    this.bestDay,
    required this.dataPoints,
  });

  factory ChartStats.empty() {
    return const ChartStats(
      totalRevenue: 0,
      totalOrders: 0,
      averageRevenue: 0,
      bestDay: null,
      dataPoints: 0,
    );
  }

  /// Revenus formatés
  String get formattedTotalRevenue => _formatNumber(totalRevenue);

  /// Revenus moyens formatés
  String get formattedAverageRevenue => _formatNumber(averageRevenue);

  /// Format court des revenus totaux
  String get shortTotalRevenue => _formatShort(totalRevenue);

  /// Format court des revenus moyens
  String get shortAverageRevenue => _formatShort(averageRevenue);

  /// Revenus du meilleur jour
  String get bestDayRevenue {
    return bestDay != null ? _formatShort(bestDay!.revenue) : '0';
  }

  String _formatNumber(double number) {
    final numberStr = number.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return numberStr.replaceAllMapped(regex, (Match match) => '${match[1]} ');
  }

  String _formatShort(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }
}

/// Utilitaires pour la gestion des animations du graphique
class ChartAnimation {
  static const Duration fast = Duration(milliseconds: 800);
  static const Duration normal = Duration(milliseconds: 1500);
  static const Duration slow = Duration(milliseconds: 2500);

  /// Courbe d'animation par défaut
  static const Curve defaultCurve = Curves.easeInOut;
  
  /// Courbe pour l'apparition des points
  static const Curve pointsCurve = Curves.elasticOut;
  
  /// Courbe pour le tracé de la ligne
  static const Curve lineCurve = Curves.easeInOut;

  /// Calculer la valeur d'animation pour un point spécifique
  static double getPointAnimation(double globalValue, int pointIndex, int totalPoints) {
    final pointDelay = pointIndex * 0.1; // Délai entre les points
    final pointValue = math.max(0.0, math.min(1.0, globalValue - pointDelay));
    return pointValue;
  }

  /// Interpoler entre deux couleurs
  static Color interpolateColor(Color start, Color end, double value) {
    return Color.lerp(start, end, value) ?? start;
  }
}

/// Tooltip pour afficher les détails d'un point
class ChartTooltip {
  final ChartPoint point;
  final Offset position;
  final String title;
  final List<String> details;
  final Color backgroundColor;
  final Color textColor;

  ChartTooltip({
    required this.point,
    required this.position,
    required this.title,
    required this.details,
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF1F2937),
  });

  /// Créer un tooltip à partir des métadonnées du point
  factory ChartTooltip.fromPoint(ChartPoint point, Offset position) {
    final metadata = point.metadata;
    
    return ChartTooltip(
      point: point,
      position: position,
      title: point.date.day.toString().padLeft(2, '0') + 
             '/${point.date.month.toString().padLeft(2, '0')}',
      details: [
        metadata['formattedRevenue'] ?? '0 FCFA',
        '${metadata['orderCount'] ?? 0} commande${(metadata['orderCount'] ?? 0) > 1 ? 's' : ''}',
        if ((metadata['averageOrderValue'] ?? 0) > 0)
          'Panier moy: ${(metadata['averageOrderValue'] as double).toStringAsFixed(0)} FCFA',
      ],
    );
  }
}