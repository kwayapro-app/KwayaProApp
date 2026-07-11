import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/enums.dart';
import '../../auth/domain/auth_providers.dart';
import '../../choir/domain/choir_providers.dart';
import '../../songs/domain/models/audio_part.dart';
import '../../songs/data/song_repository.dart';
import '../../audio/data/audio_repository.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/low_latency_piano_engine.dart';

class StudioScreen extends ConsumerStatefulWidget {
  final StudioContext? context;

  const StudioScreen({super.key, this.context});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> with TickerProviderStateMixin {
  late AudioRecorder _recorder;
  late LowLatencyPianoEngine _pianoEngine;
  AudioPlayer? _metronomePlayer;

  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  double _amplitude = 0.0;

  int _bpm = 80;
  bool _isMetronomePlaying = false;
  Timer? _metronomeTimer;

  final ScrollController _pianoScrollController = ScrollController();

  VoicePart _selectedVoicePart = VoicePart.A;
  bool _isSustain = false;

  String? _songId;
  String? _songTitle;
  String? _sectionId;
  String? _sectionTitle;
  String? _selectedKey;

  double _uploadProgress = 0.0;
  bool _isUploading = false;

  static const double _whiteKeyWidth = 60.0;
  static const double _blackKeyWidth = 42.0;

  static const List<_WhiteKeyDef> _whiteKeys = [
    _WhiteKeyDef('C3', 0), _WhiteKeyDef('D3', 1), _WhiteKeyDef('E3', 2),
    _WhiteKeyDef('F3', 3), _WhiteKeyDef('G3', 4), _WhiteKeyDef('A3', 5),
    _WhiteKeyDef('B3', 6), _WhiteKeyDef('C4', 7), _WhiteKeyDef('D4', 8),
    _WhiteKeyDef('E4', 9), _WhiteKeyDef('F4', 10), _WhiteKeyDef('G4', 11),
    _WhiteKeyDef('A4', 12), _WhiteKeyDef('B4', 13), _WhiteKeyDef('C5', 14),
    _WhiteKeyDef('D5', 15), _WhiteKeyDef('E5', 16), _WhiteKeyDef('F5', 17),
    _WhiteKeyDef('G5', 18), _WhiteKeyDef('A5', 19), _WhiteKeyDef('B5', 20),
  ];

  static const List<_BlackKeyDef> _blackKeys = [
    _BlackKeyDef('C#3', 0), _BlackKeyDef('D#3', 1),
    _BlackKeyDef('F#3', 3), _BlackKeyDef('G#3', 4), _BlackKeyDef('A#3', 5),
    _BlackKeyDef('C#4', 7), _BlackKeyDef('D#4', 8),
    _BlackKeyDef('F#4', 10), _BlackKeyDef('G#4', 11), _BlackKeyDef('A#4', 12),
    _BlackKeyDef('C#5', 14), _BlackKeyDef('D#5', 15),
    _BlackKeyDef('F#5', 17), _BlackKeyDef('G#5', 18), _BlackKeyDef('A#5', 19),
  ];

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _pianoEngine = LowLatencyPianoEngine();
    _metronomePlayer = AudioPlayer();
    _lockOrientation();

    final allNotes = [
      ..._whiteKeys.map((k) => k.note),
      ..._blackKeys.map((k) => k.note),
    ];
    _pianoEngine.initializeNotes(allNotes);

    if (widget.context != null) {
      _songId = widget.context!.songId;
      _songTitle = widget.context!.songTitle;
      _sectionId = widget.context!.sectionId;
      _sectionTitle = widget.context!.sectionTitle;
      _selectedVoicePart = widget.context!.voicePart;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToVoicePartRange());
    }
  }

  Future<void> _lockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }

  void _scrollToVoicePartRange() {
    double offset = 0.0;
    switch (_selectedVoicePart) {
      case VoicePart.S: offset = 7 * _whiteKeyWidth; break;
      case VoicePart.T: offset = 0; break;
      case VoicePart.B: offset = 0; break;
      case VoicePart.A: offset = 4 * _whiteKeyWidth; break;
    }
    if (_pianoScrollController.hasClients) {
      _pianoScrollController.animateTo(
        offset.clamp(0.0, _pianoScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _restoreOrientation();
    _recorder.dispose();
    _pianoEngine.dispose();
    _metronomePlayer?.dispose();
    _recordingTimer?.cancel();
    _metronomeTimer?.cancel();
    _pianoScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF15120B),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  SizedBox(width: 260, child: _buildLeftColumn(theme)),
                  Expanded(child: _buildCenterColumn(theme)),
                  SizedBox(width: 260, child: _buildRightColumn(theme)),
                ],
              ),
            ),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF2A251D),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: _buildPianoKeyboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text('Studio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white54), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_songTitle ?? 'Select a Song', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_sectionTitle ?? 'No section selected', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                if (_selectedKey != null) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Key: $_selectedKey', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: VoicePart.values.map((part) {
                final isSelected = _selectedVoicePart == part;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedVoicePart = part);
                      _scrollToVoicePartRange();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(part.initial, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterColumn(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 100, width: 200, child: _isRecording ? _buildWaveformVisualizer() : _buildPitchTuner()),
        const SizedBox(height: 16),
        Text(_isRecording ? 'RECORDING' : 'READY TO RECORD', style: TextStyle(color: _isRecording ? Colors.red : Colors.white54, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        if (_isRecording) Text(_formatDuration(_recordingDuration), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(height: 16),
        _isRecording
            ? GestureDetector(
                onTap: _stopRecording,
                child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.stop, color: Colors.white, size: 36)),
              )
            : SizedBox(
                width: 220,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic, size: 28),
                  label: Text('RECORD ${_selectedVoicePart.initial}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
                ),
              ),
        if (_isUploading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _uploadProgress, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Text('Uploading ${(_uploadProgress * 100).toInt()}%', style: const TextStyle(color: Colors.white54)),
        ],
      ],
    );
  }

  Widget _buildRightColumn(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          OutlinedButton(
            onPressed: _showBpmPicker,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.speed, size: 20), const SizedBox(width: 8), Text('$_bpm BPM', style: const TextStyle(fontSize: 16))]),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _toggleMetronome,
            icon: Icon(_isMetronomePlaying ? Icons.pause : Icons.play_arrow, color: _isMetronomePlaying ? Colors.green : Colors.white54),
            label: Text(_isMetronomePlaying ? 'Stop' : 'Start', style: TextStyle(color: _isMetronomePlaying ? Colors.green : Colors.white54)),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _isSustain = !_isSustain),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSustain ? theme.colorScheme.tertiaryContainer : Colors.white.withValues(alpha: 0.1),
                foregroundColor: _isSustain ? theme.colorScheme.onTertiaryContainer : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('SUSTAIN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPitchTuner() => CustomPaint(painter: _PitchTunerPainter(amplitude: _amplitude));

  Widget _buildWaveformVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(12, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 12,
          height: 20 + (math.sin(index + DateTime.now().millisecondsSinceEpoch / 100) + 1) * 40 * _amplitude,
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.7 + _amplitude * 0.3), borderRadius: BorderRadius.circular(4)),
        );
      }),
    );
  }

  Widget _buildPianoKeyboard() {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _pianoScrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _whiteKeys.length * _whiteKeyWidth,
            height: 150,
            child: Stack(
              children: [
                Row(
                  children: _whiteKeys.map((k) => _buildWhiteKey(k)).toList(),
                ),
                Positioned(
                  left: 0, top: 0, right: 0, bottom: 40,
                  child: ClipRect(
                    child: Stack(
                      children: _blackKeys.map((k) {
                        final left = (k.whiteIndex + 1) * _whiteKeyWidth - _blackKeyWidth / 2;
                        return Positioned(
                          left: left,
                          width: _blackKeyWidth,
                          top: 0,
                          bottom: 0,
                          child: _buildBlackKey(k),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: Container(width: 32, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black87, Colors.transparent])),
            child: IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: _scrollOctaveLeft)),
        ),
        Positioned(
          right: 0, top: 0, bottom: 0,
          child: Container(width: 32, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87])),
            child: IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: _scrollOctaveRight)),
        ),
      ],
    );
  }

  Widget _buildWhiteKey(_WhiteKeyDef keyDef) {
    return GestureDetector(
      onTapDown: (_) => _pianoEngine.play(keyDef.note, _isSustain),
      child: Container(
        width: _whiteKeyWidth,
        margin: const EdgeInsets.only(right: 1),
        decoration: const BoxDecoration(
          color: Color(0xFFFCFBF9),
          border: Border(right: BorderSide(color: Color(0xFFE5E0D8), width: 1)),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(keyDef.note, style: const TextStyle(fontSize: 10, color: Color(0xFF524D42)))),
        ),
      ),
    );
  }

  Widget _buildBlackKey(_BlackKeyDef keyDef) {
    return GestureDetector(
      onTapDown: (_) => _pianoEngine.play(keyDef.note, _isSustain),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A251D),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(2, 2)),
          ],
        ),
      ),
    );
  }

  void _scrollOctaveLeft() {
    final newOffset = _pianoScrollController.offset - 7 * _whiteKeyWidth;
    _pianoScrollController.animateTo(newOffset.clamp(0.0, _pianoScrollController.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _scrollOctaveRight() {
    final newOffset = _pianoScrollController.offset + 7 * _whiteKeyWidth;
    _pianoScrollController.animateTo(newOffset.clamp(0.0, _pianoScrollController.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _showBpmPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Metronome BPM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Slider(value: _bpm.toDouble(), min: 40, max: 200, divisions: 160, label: '$_bpm BPM', onChanged: (value) { setModalState(() => _bpm = value.round()); setState(() {}); }),
              Text('$_bpm BPM', style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMetronome() {
    if (_isMetronomePlaying) { _metronomeTimer?.cancel(); setState(() => _isMetronomePlaying = false); }
    else { setState(() => _isMetronomePlaying = true); _metronomeTimer = Timer.periodic(Duration(milliseconds: 60000 ~/ _bpm), (timer) {}); }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Microphone Permission Required'),
            content: const Text('Please grant microphone permission to record audio.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(onPressed: () { Navigator.pop(context); openAppSettings(); }, child: const Text('Open Settings')),
            ],
          ),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100), path: path);

      setState(() { _isRecording = true; _recordingDuration = Duration.zero; });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) { setState(() => _recordingDuration += const Duration(seconds: 1)); });

      _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) { final normalized = (amp.current + 60) / 60; setState(() => _amplitude = normalized.clamp(0.0, 1.0)); });

      if (!_isMetronomePlaying) _toggleMetronome();
    } catch (e) {
      AppLogger.error('Failed to start recording', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start recording. Check microphone access and try again.')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (_isMetronomePlaying) _toggleMetronome();

    final recordingPath = await _recorder.stop();

    if (recordingPath != null && mounted) {
      setState(() => _isRecording = false);
      await _uploadRecording(recordingPath);
    }
  }

  Future<void> _uploadRecording(String recordingPath) async {
    if (_songId == null || _sectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a song and section first')));
      return;
    }

    final choirId = ref.read(activeChoirIdProvider);
    final userId = ref.read(currentUserIdProvider);
    if (choirId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active choir or user. Please try again.')));
      return;
    }

    setState(() { _isUploading = true; _uploadProgress = 0.0; });

    try {
      final audioRepo = AudioRepository();
      final downloadUrl = await audioRepo.uploadRecordedAudio(choirId: choirId, songId: _songId!, sectionId: _sectionId!, voicePart: _selectedVoicePart, recordingPath: recordingPath, onProgress: (progress) { setState(() => _uploadProgress = progress); });

      final songRepo = SongRepository();
      final audioPart = AudioPart(audioPartId: const Uuid().v4(), sectionId: _sectionId!, songId: _songId!, choirId: choirId, voicePart: _selectedVoicePart, audioUrl: downloadUrl, durationSeconds: _recordingDuration.inSeconds, uploadedBy: userId, createdAt: DateTime.now());

      await songRepo.createAudioPart(audioPart);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. Choristers have been notified.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading: $e'))); }
    finally { setState(() => _isUploading = false); }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _WhiteKeyDef {
  final String note;
  final int index;
  const _WhiteKeyDef(this.note, this.index);
}

class _BlackKeyDef {
  final String note;
  final int whiteIndex;
  const _BlackKeyDef(this.note, this.whiteIndex);
}

class _PitchTunerPainter extends CustomPainter {
  final double amplitude;
  _PitchTunerPainter({required this.amplitude});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi, false, bgPaint);

    final greenPaint = Paint()..color = Colors.green.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi + 0.3, math.pi * 0.4, false, greenPaint);

    final needleAngle = math.pi + (amplitude * math.pi * 0.8);
    final needleEnd = Offset(center.dx + (radius - 20) * math.cos(needleAngle), center.dy + (radius - 20) * math.sin(needleAngle));
    final needlePaint = Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    final dotPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PitchTunerPainter oldDelegate) => oldDelegate.amplitude != amplitude;
}

class StudioContext {
  final String songId;
  final String songTitle;
  final String sectionId;
  final String sectionTitle;
  final VoicePart voicePart;

  StudioContext({required this.songId, required this.songTitle, required this.sectionId, required this.sectionTitle, required this.voicePart});
}
