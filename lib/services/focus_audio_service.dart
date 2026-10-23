import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AmbientSoundTrack {
  final String id;
  final String name;
  final String subtitle;
  final String category;
  final String description;

  const AmbientSoundTrack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    required this.description,
  });
}

class FocusAudioService extends ChangeNotifier {
  static final FocusAudioService instance = FocusAudioService._internal();
  FocusAudioService._internal();

  static const MethodChannel _channel = MethodChannel('com.focusflow.app/usage');

  static const List<AmbientSoundTrack> availableTracks = [
    AmbientSoundTrack(
      id: 'binaural_gamma',
      name: '40Hz Gamma Flow',
      subtitle: 'Deep Focus & Flow State',
      category: 'Binaural Beats',
      description: 'Synthesized 40Hz beat designed to boost cognitive focus and working memory (headphones recommended).',
    ),
    AmbientSoundTrack(
      id: 'binaural_alpha',
      name: '10Hz Alpha Calm',
      subtitle: 'Creative Flow & Alert Relaxation',
      category: 'Binaural Beats',
      description: 'Promotes relaxed alertness and reduces stress during high-friction tasks.',
    ),
    AmbientSoundTrack(
      id: 'white_noise',
      name: 'Pink & White Noise',
      subtitle: 'Distraction Shield',
      category: 'Sound Barrier',
      description: 'Smooth filtered acoustic barrier to mask chatter and background office noise.',
    ),
    AmbientSoundTrack(
      id: 'rain',
      name: 'Gentle Rainstorm',
      subtitle: 'Steady Rhythmic Drops',
      category: 'Nature',
      description: 'Natural ambient rain soundscape to soothe racing thoughts.',
    ),
    AmbientSoundTrack(
      id: 'ocean',
      name: 'Ocean Waves',
      subtitle: 'Tidal Rhythm & Serenity',
      category: 'Nature',
      description: 'Continuous deep ocean swells providing an expansive, grounding presence.',
    ),
    AmbientSoundTrack(
      id: 'forest',
      name: 'Deep Forest',
      subtitle: 'Woodland Wind & Birds',
      category: 'Nature',
      description: 'Refreshing wilderness ambiance creating an open, inspiring workspace.',
    ),
  ];

  bool _isPlaying = false;
  String? _activeTrackId;
  double _volume = 0.7;
  bool _initialized = false;

  bool get isPlaying => _isPlaying;
  String? get activeTrackId => _activeTrackId;
  double get volume => _volume;

  AmbientSoundTrack? get activeTrack {
    if (_activeTrackId == null) return null;
    try {
      return availableTracks.firstWhere((t) => t.id == _activeTrackId);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble('focus_audio_volume') ?? 0.7;
      _activeTrackId = prefs.getString('focus_audio_last_track') ?? 'binaural_gamma';

      final currentlyPlaying = await _channel.invokeMethod<bool>('isAmbientPlaying') ?? false;
      final currentSound = await _channel.invokeMethod<String>('getCurrentAmbientSound');

      if (currentlyPlaying && currentSound != null && currentSound.isNotEmpty) {
        _isPlaying = true;
        _activeTrackId = currentSound;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('FocusAudioService init error: $e');
    }
  }

  Future<void> playTrack(String trackId) async {
    try {
      final success = await _channel.invokeMethod<bool>('playAmbientSound', {
        'sound': trackId,
        'volume': _volume,
      }) ?? false;

      if (success) {
        _isPlaying = true;
        _activeTrackId = trackId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('focus_audio_last_track', trackId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error playing sound $trackId: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopAmbientSound');
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping ambient sound: $e');
    }
  }

  Future<void> toggleTrack(String trackId) async {
    if (_isPlaying && _activeTrackId == trackId) {
      await stop();
    } else {
      await playTrack(trackId);
    }
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _channel.invokeMethod('setAmbientVolume', {'volume': _volume});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('focus_audio_volume', _volume);
    } catch (e) {
      debugPrint('Error setting ambient volume: $e');
    }
  }
}
