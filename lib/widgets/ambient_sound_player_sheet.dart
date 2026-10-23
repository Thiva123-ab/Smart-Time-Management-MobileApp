import 'package:flutter/material.dart';
import '../services/focus_audio_service.dart';
import '../theme/app_theme.dart';

class AmbientSoundPlayerSheet extends StatefulWidget {
  const AmbientSoundPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AmbientSoundPlayerSheet(),
    );
  }

  @override
  State<AmbientSoundPlayerSheet> createState() => _AmbientSoundPlayerSheetState();
}

class _AmbientSoundPlayerSheetState extends State<AmbientSoundPlayerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  IconData _getTrackIcon(String id) {
    switch (id) {
      case 'binaural_gamma':
        return Icons.bolt_rounded;
      case 'binaural_alpha':
        return Icons.spa_rounded;
      case 'white_noise':
        return Icons.graphic_eq_rounded;
      case 'rain':
        return Icons.water_drop_rounded;
      case 'ocean':
        return Icons.tsunami_rounded;
      case 'forest':
        return Icons.forest_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  Color _getTrackColor(String id) {
    switch (id) {
      case 'binaural_gamma':
        return AppColors.accentCyan;
      case 'binaural_alpha':
        return const Color(0xFF8B5CF6); // Violet
      case 'white_noise':
        return const Color(0xFFEC4899); // Pink
      case 'rain':
        return const Color(0xFF38BDF8); // Sky blue
      case 'ocean':
        return const Color(0xFF0EA5E9); // Ocean blue
      case 'forest':
        return const Color(0xFF10B981); // Emerald green
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audio = FocusAudioService.instance;

    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final isPlaying = audio.isPlaying;
        final activeTrack = audio.activeTrack;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131826) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.cardBorder(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMutedColor(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.accentCyan,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Soundscapes',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        Text(
                          'Binaural beats & acoustic soundscapes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondaryColor(context),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active Playing Banner & Waveform Visualizer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1)
                      : AppColors.surface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isPlaying
                        ? AppColors.accentCyan.withValues(alpha: 0.6)
                        : AppColors.cardBorder(context),
                    width: isPlaying ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Animated Waveform / Equalizer Bars
                    _buildAnimatedWaveform(isPlaying),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPlaying && activeTrack != null
                                ? activeTrack.name
                                : 'Playback Paused',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPlaying
                                  ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                  : AppColors.textSecondaryColor(context),
                            ),
                          ),
                          Text(
                            isPlaying && activeTrack != null
                                ? 'Now Playing • ${activeTrack.category}'
                                : 'Select a soundscape below to begin',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMutedColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPlaying)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900.withValues(alpha: 0.4),
                          foregroundColor: Colors.red.shade200,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 16),
                        label: const Text('Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => audio.stop(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Volume Slider
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      audio.volume == 0
                          ? Icons.volume_off_rounded
                          : (audio.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      color: isDark ? AppColors.accentCyan : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          activeTrackColor: isDark ? AppColors.accentCyan : AppColors.primary,
                          inactiveTrackColor: AppColors.textMutedColor(context).withValues(alpha: 0.2),
                          thumbColor: isDark ? AppColors.accentCyan : AppColors.primary,
                        ),
                        child: Slider(
                          value: audio.volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) => audio.setVolume(val),
                        ),
                      ),
                    ),
                    Text(
                      '${(audio.volume * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'SOUND LIBRARY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textMutedColor(context),
                ),
              ),
              const SizedBox(height: 10),

              // Scrollable list of soundscapes
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: FocusAudioService.availableTracks.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final track = FocusAudioService.availableTracks[index];
                    final isThisActive = isPlaying && audio.activeTrackId == track.id;
                    final trackColor = _getTrackColor(track.id);

                    return InkWell(
                      onTap: () => audio.toggleTrack(track.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isThisActive
                              ? trackColor.withValues(alpha: isDark ? 0.2 : 0.12)
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isThisActive
                                ? trackColor
                                : AppColors.cardBorder(context),
                            width: isThisActive ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: trackColor.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getTrackIcon(track.id),
                                color: trackColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        track.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isThisActive
                                              ? trackColor
                                              : AppColors.textPrimaryColor(context),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: trackColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          track.category,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: trackColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryColor(context),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isThisActive
                                    ? trackColor
                                    : AppColors.surfaceVariant(context),
                              ),
                              child: Icon(
                                isThisActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: isThisActive ? Colors.white : AppColors.textPrimaryColor(context),
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedWaveform(bool isPlaying) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final heights = isPlaying
            ? [
                12.0 + 16.0 * _animController.value,
                24.0 - 14.0 * _animController.value,
                16.0 + 12.0 * (1.0 - _animController.value),
                22.0 * _animController.value + 8.0,
              ]
            : [8.0, 8.0, 8.0, 8.0];

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: heights.map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: h.clamp(6.0, 28.0),
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.accentCyan : AppColors.textMutedColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
