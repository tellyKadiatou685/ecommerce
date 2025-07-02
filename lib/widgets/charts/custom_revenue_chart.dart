// lib/widgets/charts/custom_revenue_chart.dart - GRAPHIQUE AMÉLIORÉ AVEC MODÈLES

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/merchant_stats_model.dart';
import '../../models/chart_models.dart';

class CustomRevenueChart extends StatefulWidget {
  final List<RevenueChartData> data;
  final double height;
  final ChartConfig? config;
  final bool enableInteraction;
  final Function(ChartPoint?)? onPointTap;

  const CustomRevenueChart({
    Key? key,
    required this.data,
    this.height = 200,
    this.config,
    this.enableInteraction = false,
    this.onPointTap,
  }) : super(key: key);

  @override
  State<CustomRevenueChart> createState() => _CustomRevenueChartState();
}

class _CustomRevenueChartState extends State<CustomRevenueChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  ChartData? _chartData;
  ChartPoint? _selectedPoint;
  ChartTooltip? _tooltip;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    final config = widget.config ?? ChartConfig.revenue;
    _animationController = AnimationController(
      duration: Duration(milliseconds: config.animationDuration.round()),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: ChartAnimation.defaultCurve),
    );
    
    if (config.enableAnimation) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CustomRevenueChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data || oldWidget.config != widget.config) {
      _chartData = null; // Force recalcul
      if (widget.config?.enableAnimation ?? true) {
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enableInteraction || _chartData == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    final nearestPoint = _chartData!.findNearestPoint(localPosition);
    
    setState(() {
      _selectedPoint = nearestPoint;
      if (nearestPoint != null) {
        _tooltip = ChartTooltip.fromPoint(nearestPoint, localPosition);
        widget.onPointTap?.call(nearestPoint);
        
        // Auto-hide après 3 secondes
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _selectedPoint = null;
              _tooltip = null;
            });
          }
        });
      } else {
        _tooltip = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config ?? ChartConfig.revenue;
    
    if (widget.data.isEmpty) {
      return _buildEmptyState(config);
    }

    return GestureDetector(
      onTapDown: widget.enableInteraction ? _handleTapDown : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: config.backgroundColor,
                ),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: ImprovedChartPainter(
                    data: widget.data,
                    config: config,
                    animationValue: _animation.value,
                    selectedPoint: _selectedPoint,
                  ),
                ),
              ),
              
              // Tooltip
              if (_tooltip != null) _buildTooltip(_tooltip!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ChartConfig config) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: config.backgroundColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.gridColor),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: config.labelColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Aucune donnée disponible',
              style: TextStyle(
                color: config.labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(ChartTooltip tooltip) {
    return Positioned(
      left: tooltip.position.dx - 80,
      top: tooltip.position.dy - 80,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tooltip.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.config?.primaryColor.withOpacity(0.2) ?? Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tooltip.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.config?.primaryColor ?? Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              ...tooltip.details.map((detail) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: tooltip.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class ImprovedChartPainter extends CustomPainter {
  final List<RevenueChartData> data;
  final ChartConfig config;
  final double animationValue;
  final ChartPoint? selectedPoint;

  ImprovedChartPainter({
    required this.data,
    required this.config,
    required this.animationValue,
    this.selectedPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Créer ChartData
    final chartData = ChartData.fromRevenueData(data, size, config);

    // Dessiner les éléments dans l'ordre
    if (config.showGrid) _drawGrid(canvas, chartData);
    if (config.showGradient) _drawGradientArea(canvas, chartData);
    _drawMainLine(canvas, chartData);
    if (config.showPoints) _drawDataPoints(canvas, chartData);
    if (config.showLabels) _drawLabels(canvas, chartData);
    if (selectedPoint != null) _drawSelectedPoint(canvas, selectedPoint!);
  }

  void _drawGrid(Canvas canvas, ChartData chartData) {
    final gridPaint = Paint()
      ..color = config.gridColor.withOpacity(0.3)
      ..strokeWidth = 1;

    final rect = chartData.chartRect;

    // Lignes horizontales
    for (int i = 0; i <= 4; i++) {
      final y = rect.top + (rect.height / 4) * i;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        gridPaint,
      );
    }

    // Lignes verticales
    if (chartData.points.length > 1) {
      final stepX = rect.width / (chartData.points.length - 1);
      for (int i = 0; i < chartData.points.length; i++) {
        final x = rect.left + stepX * i;
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x, rect.bottom),
          gridPaint,
        );
      }
    }
  }

  void _drawGradientArea(Canvas canvas, ChartData chartData) {
    final animatedPoints = chartData.getAnimatedPoints(animationValue);
    if (animatedPoints.length < 2) return;

    final path = Path();
    path.moveTo(animatedPoints.first.x, chartData.chartRect.bottom);
    path.lineTo(animatedPoints.first.x, animatedPoints.first.y);

    // Créer une courbe lisse
    for (int i = 1; i < animatedPoints.length; i++) {
      if (i == 1) {
        path.lineTo(animatedPoints[i].x, animatedPoints[i].y);
      } else {
        final cp1x = animatedPoints[i - 1].x + 
                    (animatedPoints[i].x - animatedPoints[i - 1].x) * 0.5;
        final cp1y = animatedPoints[i - 1].y;
        final cp2x = animatedPoints[i].x - 
                    (animatedPoints[i].x - animatedPoints[i - 1].x) * 0.5;
        final cp2y = animatedPoints[i].y;
        
        path.cubicTo(cp1x, cp1y, cp2x, cp2y, animatedPoints[i].x, animatedPoints[i].y);
      }
    }

    path.lineTo(animatedPoints.last.x, chartData.chartRect.bottom);
    path.lineTo(animatedPoints.first.x, chartData.chartRect.bottom);
    path.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          config.gradientStartColor.withOpacity(0.3),
          config.gradientEndColor.withOpacity(0.05),
        ],
      ).createShader(chartData.chartRect);

    canvas.drawPath(path, gradientPaint);
  }

  void _drawMainLine(Canvas canvas, ChartData chartData) {
    final animatedPoints = chartData.getAnimatedPoints(animationValue);
    if (animatedPoints.length < 2) return;

    final linePaint = Paint()
      ..color = config.primaryColor
      ..strokeWidth = config.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(animatedPoints.first.x, animatedPoints.first.y);

    // Créer une courbe lisse
    for (int i = 1; i < animatedPoints.length; i++) {
      if (i == 1) {
        path.lineTo(animatedPoints[i].x, animatedPoints[i].y);
      } else {
        final cp1x = animatedPoints[i - 1].x + 
                    (animatedPoints[i].x - animatedPoints[i - 1].x) * 0.5;
        final cp1y = animatedPoints[i - 1].y;
        final cp2x = animatedPoints[i].x - 
                    (animatedPoints[i].x - animatedPoints[i - 1].x) * 0.5;
        final cp2y = animatedPoints[i].y;
        
        path.cubicTo(cp1x, cp1y, cp2x, cp2y, animatedPoints[i].x, animatedPoints[i].y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  void _drawDataPoints(Canvas canvas, ChartData chartData) {
    final animatedPoints = chartData.getAnimatedPoints(animationValue);
    
    for (int i = 0; i < animatedPoints.length; i++) {
      final point = animatedPoints[i];
      
      // Animation: faire apparaître les points un par un
      final pointAnimationValue = ChartAnimation.getPointAnimation(
        animationValue, i, animatedPoints.length);
      
      if (pointAnimationValue > 0) {
        final radius = config.pointRadius * pointAnimationValue;
        final innerRadius = (config.pointRadius - 2) * pointAnimationValue;
        
        // Point extérieur (blanc)
        final outerPaint = Paint()
          ..color = config.backgroundColor
          ..style = PaintingStyle.fill;
        
        // Point intérieur (couleur principale)
        final innerPaint = Paint()
          ..color = config.primaryColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(point.offset, radius, outerPaint);
        canvas.drawCircle(point.offset, innerRadius, innerPaint);
      }
    }
  }

  void _drawLabels(Canvas canvas, ChartData chartData) {
    final labelStyle = TextStyle(
      color: config.labelColor,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    // Labels X (jours)
    for (final label in chartData.xAxisLabels) {
      final textPainter = TextPainter(
        text: TextSpan(text: label.text, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final textOffset = Offset(
        label.position.dx - textPainter.width / 2,
        label.position.dy,
      );
      
      textPainter.paint(canvas, textOffset);
    }

    // Labels Y (revenus)
    for (final label in chartData.yAxisLabels) {
      final textPainter = TextPainter(
        text: TextSpan(text: label.text, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final textOffset = Offset(
        label.position.dx - textPainter.width,
        label.position.dy - textPainter.height / 2,
      );
      
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawSelectedPoint(Canvas canvas, ChartPoint point) {
    // Cercle de surbrillance
    final highlightPaint = Paint()
      ..color = config.primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(point.offset, 15, highlightPaint);

    // Point principal agrandi
    final outerPaint = Paint()
      ..color = config.backgroundColor
      ..style = PaintingStyle.fill;
    
    final innerPaint = Paint()
      ..color = config.primaryColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(point.offset, config.pointRadius + 2, outerPaint);
    canvas.drawCircle(point.offset, config.pointRadius - 1, innerPaint);
  }

  @override
  bool shouldRepaint(ImprovedChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.data != data ||
           oldDelegate.selectedPoint != selectedPoint ||
           oldDelegate.config != config;
  }
}