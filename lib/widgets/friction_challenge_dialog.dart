import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum FrictionType { math, mindfulPause, intentionType }

class FrictionChallengeDialog extends StatefulWidget {
  final String appName;
  final VoidCallback? onSuccess;

  const FrictionChallengeDialog({
    super.key,
    required this.appName,
    this.onSuccess,
  });

  static Future<bool?> show(BuildContext context, {required String appName, VoidCallback? onSuccess}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FrictionChallengeDialog(appName: appName, onSuccess: onSuccess),
    );
  }

  @override
  State<FrictionChallengeDialog> createState() => _FrictionChallengeDialogState();
}

class _FrictionChallengeDialogState extends State<FrictionChallengeDialog>
    with SingleTickerProviderStateMixin {
  FrictionType _selectedType = FrictionType.math;

  // Math State
  late int _numA;
  late int _numB;
  late int _expectedSum;
  final TextEditingController _mathController = TextEditingController();
  String? _mathError;

  // Mindful Pause State
  int _secondsLeft = 20;
  Timer? _countdownTimer;
  bool _isPausing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Intention Typed State
  final String _targetStatement = "I am intentionally opening this app";
  final TextEditingController _intentController = TextEditingController();
  String? _intentError;

  @override
  void initState() {
    super.initState();
    _generateMath();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _generateMath() {
    final rand = Random();
    _numA = rand.nextInt(45) + 25;
    _numB = rand.nextInt(40) + 18;
    _expectedSum = _numA + _numB;
    _mathController.clear();
    _mathError = null;
  }

  void _startMindfulPause() {
    setState(() {
      _isPausing = true;
      _secondsLeft = 20;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _isPausing = false;
        });
        _completeChallenge();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _verifyMath() {
    final val = int.tryParse(_mathController.text.trim());
    if (val == _expectedSum) {
      _completeChallenge();
    } else {
      setState(() {
        _mathError = 'Incorrect answer. Take a moment and try again!';
        _generateMath();
      });
    }
  }

  void _verifyIntention() {
    if (_intentController.text.trim().toLowerCase() == _targetStatement.toLowerCase()) {
      _completeChallenge();
    } else {
      setState(() {
        _intentError = 'Sentence does not match exactly. Type carefully.';
      });
    }
  }

  void _completeChallenge() {
    widget.onSuccess?.call();
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _mathController.dispose();
    _intentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141926) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.cardBorder(context), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Friction Barrier',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Break the autopilot loop for ${widget.appName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMutedColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Challenge Type Tabs
              Row(
                children: [
                  _typeTab('🧮 Math', FrictionType.math),
                  const SizedBox(width: 8),
                  _typeTab('🧘 Breath', FrictionType.mindfulPause),
                  const SizedBox(width: 8),
                  _typeTab('✍️ Typed', FrictionType.intentionType),
                ],
              ),
              const SizedBox(height: 20),

              // Challenge Body
              if (_selectedType == FrictionType.math) _buildMathView(context),
              if (_selectedType == FrictionType.mindfulPause) _buildMindfulPauseView(context),
              if (_selectedType == FrictionType.intentionType) _buildIntentionView(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTab(String title, FrictionType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _mathError = null;
            _intentError = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMathView(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          child: Column(
            children: [
              Text(
                'Solve to Prove Awareness',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_numA  +  $_numB  =  ?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.accentCyan,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _mathController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Your Answer',
            errorText: _mathError,
            filled: true,
            fillColor: AppColors.surfaceVariant(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.cardBorder(context)),
            ),
          ),
          onSubmitted: (_) => _verifyMath(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _verifyMath,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 18),
              SizedBox(width: 8),
              Text('Unlock 5-Min Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMindfulPauseView(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentCyan.withValues(alpha: 0.35),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: AppColors.accentCyan, width: 2),
            ),
            child: Center(
              child: Text(
                _isPausing ? '$_secondsLeft s' : '20s',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentCyan,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isPausing
              ? (_secondsLeft % 6 >= 3 ? 'Breathe in slowly...' : 'Breathe out gently...')
              : 'Take a conscious 20-second pause before proceeding.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isPausing ? AppColors.surfaceVariant(context) : AppColors.accentCyan,
            foregroundColor: _isPausing ? AppColors.textMutedColor(context) : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isPausing ? null : _startMindfulPause,
          child: Text(
            _isPausing ? 'Mindful Breathing...' : 'Begin 20s Breath Pause',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildIntentionView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type the statement below to confirm conscious intent:',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          child: Text(
            '"$_targetStatement"',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: AppColors.primaryLight,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _intentController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Type statement here...',
            errorText: _intentError,
            filled: true,
            fillColor: AppColors.surfaceVariant(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder(context)),
            ),
          ),
          onSubmitted: (_) => _verifyIntention(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _verifyIntention,
          child: const Text('Confirm & Unlock 5m Pass', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
