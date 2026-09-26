import 'dart:async';
import 'package:flutter/material.dart';

class HomeworkTimer extends StatefulWidget {
  final DateTime deadline;
  const HomeworkTimer({Key? key, required this.deadline}) : super(key: key);

  @override
  State<HomeworkTimer> createState() => _HomeworkTimerState();
}

class _HomeworkTimerState extends State<HomeworkTimer> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _timeLeft;
  bool _isExpired = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeLeft());
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (widget.deadline.isBefore(now)) {
      if (!_isExpired && mounted) {
        setState(() {
          _isExpired = true;
          _timeLeft = Duration.zero;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = widget.deadline.difference(now);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_rounded, size: 15, color: Color(0xFFDC2626)),
            SizedBox(width: 5),
            Text(
              'انتهى موعد التسليم',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    final isUrgent = _timeLeft.inHours < 2;
    final isWarning = _timeLeft.inHours < 12;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData iconData;

    if (isUrgent) {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFF87171);
      textColor = const Color(0xFFDC2626);
      iconData = Icons.alarm_rounded;
    } else if (isWarning) {
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFFBBF24);
      textColor = const Color(0xFFD97706);
      iconData = Icons.access_time_filled_rounded;
    } else {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF6EE7B7);
      textColor = const Color(0xFF059669);
      iconData = Icons.timer_rounded;
    }

    String timeString = '';
    if (_timeLeft.inDays > 0) {
      timeString = '${_timeLeft.inDays} يوم و ${_timeLeft.inHours % 24} س';
    } else if (_timeLeft.inHours > 0) {
      timeString = '${_timeLeft.inHours} ساعة و ${_timeLeft.inMinutes % 60} د';
    } else {
      timeString = '${_timeLeft.inMinutes} دقيقة و ${_timeLeft.inSeconds % 60} ث';
    }

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 15, color: textColor),
          const SizedBox(width: 5),
          Text(
            'متبقي: $timeString',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (isUrgent) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: content,
      );
    }

    return content;
  }
}
