import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/scanner_service.dart';

// Scanner view states
enum _ViewState { camera, processing, confirm, cardReview, pdfResult }

class ScannerScreen extends StatefulWidget {
  final int initialMode;
  final String? initialImagePath;
  const ScannerScreen({super.key, this.initialMode = 0, this.initialImagePath});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const platform = MethodChannel('com.simon.simplecard/camera');
  final ScannerService _scannerService = ScannerService();

  // State
  List<OcrBlock> _ocrBlocks = [];

  _ViewState _view = _ViewState.camera;
  String _processingMsg = '';

  // Camera
  CameraController? _cameraController;
  CameraMacOSController? _macOsController;
  final GlobalKey _macOsCameraKey = GlobalKey();
  bool _macOsCameraStarted = false;
  bool _isCameraReady = false;
  bool _isCameraError = false;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  FlashMode _flashMode = FlashMode.off;

  // Capture mode: 0=Single, 1=Continuous
  int _captureMode = 0;
  final List<String> _continuousImages = [];

  // Detection
  Map<String, double>? _detectedCorners;
  Map<String, double>? _smoothedCorners; // Interpolated corners for smooth display
  double _frameWidth = 0; // Raw camera frame width from native
  double _frameHeight = 0; // Raw camera frame height from native
  bool _isFrameRotated = true; // Whether Vision applied .right rotation
  bool _isStreaming = false;
  DateTime? _lastDetectionTime;
  bool _isDetecting = false;
  // Track consecutive detections for stability
  int _consecutiveDetections = 0;
  int _consecutiveMisses = 0;
  static const _detectionThreshold = 3;
  static const _missThreshold = 5;

  // Auto-capture: trigger when corners are stable
  DateTime? _stableStartTime;
  Map<String, double>? _lastStableCorners;
  bool _isAutoCapturing = false;
  static const _autoCaptureDuration = Duration(milliseconds: 1500); // Hold 1.5s to auto-capture
  static const _stabilityThreshold = 0.02; // Max normalized movement to consider "stable"

  // Capture results
  String? _capturedPath;
  String? _correctedPath;
  String? _detectedType; // 'card' or 'document'
  String? _pdfPath;

  // Animations
  late AnimationController _frameAnimController;
  late Animation<double> _frameGlowAnim;

  // Auto-capture progress animation
  late AnimationController _autoCaptureAnimController;

  // OCR Fields
  String _name = '', _company = '', _title = '';
  String _tel = '', _mobile = '', _email = '';
  String _address = '', _website = '';

  @override
  void initState() {
    super.initState();
    _captureMode = widget.initialMode;
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _frameAnimController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _frameGlowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _frameAnimController, curve: Curves.easeInOut));
    _frameAnimController.repeat(reverse: true);

    _autoCaptureAnimController = AnimationController(
      vsync: this, duration: _autoCaptureDuration);

    if (widget.initialImagePath != null) {
      _capturedPath = widget.initialImagePath;
      _view = _ViewState.processing;
      _processOcr(widget.initialImagePath!);
      if (!Platform.isMacOS) _initCamera(); // Init camera in background for 'Retake'
    } else {
      if (Platform.isMacOS) {
        _initCameraMacos();
      } else {
        _initCamera();
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.removeObserver(this);
    _frameAnimController.dispose();
    _autoCaptureAnimController.dispose();
    _stopStream();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionPermanentlyDenied) {
      _initCamera();
    } else if (state == AppLifecycleState.inactive) {
      _stopStream();
      _cameraController?.dispose();
    }
  }

  // ═══════════════════════════════════════════════════
  //  CAMERA
  // ═══════════════════════════════════════════════════

  Future<void> _initCameraMacos() async {
    setState(() {
      _isCameraError = false;
      _macOsCameraStarted = true;
      _isCameraReady = true;
    });
  }

  Future<void> _initCamera() async {
    final perm = await _scannerService.requestCameraPermission();
    if (perm != CameraPermissionResult.granted) {
      if (mounted) setState(() {
        _permissionDenied = true;
        _permissionPermanentlyDenied = perm == CameraPermissionResult.permanentlyDenied;
        _isCameraError = true;
      });
      return;
    }
    setState(() { _permissionDenied = false; _permissionPermanentlyDenied = false; _isCameraError = false; });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { if (mounted) setState(() => _isCameraError = true); return; }
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      _cameraController = CameraController(back, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.bgra8888);
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(_flashMode);
      try { await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp); } catch (_) {}
      try { await _cameraController!.setFocusMode(FocusMode.auto); } catch (_) {}

      if (mounted) {
        setState(() => _isCameraReady = true);
        // Defer stream start so camera preview shows instantly
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _startStream(); });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraError = true);
    }
  }

  // ═══════════════════════════════════════════════════
  //  LIVE DETECTION STREAM with smooth interpolation
  // ═══════════════════════════════════════════════════

  void _startStream() {
    if (_isStreaming) return;
    
    if (Platform.isMacOS) {
      if (_macOsController == null) return;
      try {
        _macOsController!.startImageStream((CameraImageData? image) {
          if (image == null) return;
          _onFrameMacos(image);
        });
        _isStreaming = true;
      } catch (e) { debugPrint('Mac Stream start error: $e'); }
      return;
    }

    if (_cameraController == null) return;
    try {
      _cameraController!.startImageStream(_onFrame);
      _isStreaming = true;
    } catch (e) { debugPrint('Stream start error: $e'); }
  }

  void _stopStream() {
    if (!_isStreaming) return;
    
    if (Platform.isMacOS) {
      if (_macOsController != null) {
        try {
          _macOsController!.stopImageStream();
          _isStreaming = false;
        } catch (_) {}
      }
      return;
    }

    if (_cameraController == null) return;
    try {
      _cameraController!.stopImageStream();
      _isStreaming = false;
    } catch (_) {}
  }

  void _onFrame(CameraImage image) {
    if (_isDetecting || _isAutoCapturing) return;
    final now = DateTime.now();
    if (_lastDetectionTime != null && now.difference(_lastDetectionTime!) < const Duration(milliseconds: 80)) return;
    _lastDetectionTime = now;
    _isDetecting = true;

    final bytes = Uint8List.fromList(image.planes[0].bytes);
    platform.invokeMethod('detectRectangleLive', {
      'bytes': bytes,
      'width': image.width,
      'height': image.height,
      'bytesPerRow': image.planes[0].bytesPerRow,
    }).then((result) {
      if (!mounted) return;
      if (result != null) {
        _consecutiveDetections++;
        _consecutiveMisses = 0;
        final allData = Map<String, double>.from(result as Map);
        
        // Extract frame metadata (not corners) — safely remove
        allData.remove('frameWidth');
        allData.remove('frameHeight');
        allData.remove('isRotated');
        
        // Remaining entries are corner coordinates
        final newCorners = allData;

        if (_consecutiveDetections >= _detectionThreshold) {
          // Smooth interpolation: lerp from current to new corners
          final smoothed = _smoothedCorners != null
            ? _lerpCorners(_smoothedCorners!, newCorners, 0.5) // 50% blend toward new for tighter tracking
            : newCorners;

          setState(() {
            _detectedCorners = newCorners;
            _smoothedCorners = smoothed;
          });

          // Check stability for auto-capture
          _checkAutoCapture(newCorners);
        }
      } else {
        _consecutiveMisses++;
        _consecutiveDetections = 0;
        if (_consecutiveMisses >= _missThreshold) {
          setState(() { _detectedCorners = null; _smoothedCorners = null; });
          _resetAutoCapture();
        }
      }
    }).catchError((e) {
      debugPrint('Detection error: $e');
    }).whenComplete(() => _isDetecting = false);
  }

  /// Linearly interpolate between two sets of corners (null-safe)
  Map<String, double> _lerpCorners(Map<String, double> from, Map<String, double> to, double t) {
    final result = <String, double>{};
    for (var key in to.keys) {
      final fromVal = from[key] ?? to[key]!;
      result[key] = fromVal + (to[key]! - fromVal) * t;
    }
    return result;
  }

  /// Check if corners are stable enough for auto-capture
  void _checkAutoCapture(Map<String, double> corners) {
    if (_captureMode == 1) return; // No auto-capture in continuous mode

    if (_lastStableCorners != null) {
      // Calculate max corner movement (null-safe)
      double maxDelta = 0;
      for (var key in corners.keys) {
        final prev = _lastStableCorners![key];
        if (prev == null) continue;
        final delta = (corners[key]! - prev).abs();
        if (delta > maxDelta) maxDelta = delta;
      }

      if (maxDelta < _stabilityThreshold) {
        // Corners are stable
        if (_stableStartTime == null) {
          _stableStartTime = DateTime.now();
          _autoCaptureAnimController.forward(from: 0);
        } else {
          final elapsed = DateTime.now().difference(_stableStartTime!);
          if (elapsed >= _autoCaptureDuration && !_isAutoCapturing) {
            // Auto-capture!
            _isAutoCapturing = true;
            _captureImage();
          }
        }
      } else {
        // Corners moved — reset stability
        _resetAutoCapture();
      }
    }
    _lastStableCorners = Map<String, double>.from(corners);
  }

  void _resetAutoCapture() {
    _stableStartTime = null;
    _lastStableCorners = null;
    _isAutoCapturing = false;
    if (_autoCaptureAnimController.isAnimating) {
      _autoCaptureAnimController.stop();
      _autoCaptureAnimController.reset();
    }
  }

  void _onFrameMacos(CameraImageData image) {
    if (_isDetecting || _isAutoCapturing) return;
    final now = DateTime.now();
    if (_lastDetectionTime != null && now.difference(_lastDetectionTime!) < const Duration(milliseconds: 80)) return;
    _lastDetectionTime = now;
    _isDetecting = true;

    platform.invokeMethod('detectRectangleLive', {
      'bytes': image.bytes,
      'width': image.width,
      'height': image.height,
      'bytesPerRow': image.bytesPerRow,
    }).then((result) {
      if (!mounted) return;
      if (result != null) {
        _consecutiveDetections++;
        _consecutiveMisses = 0;
        final allData = Map<String, double>.from(result as Map);
        
        allData.remove('frameWidth');
        allData.remove('frameHeight');
        allData.remove('isRotated');
        
        final newCorners = allData;

        if (_consecutiveDetections >= _detectionThreshold) {
          final smoothed = _smoothedCorners != null
            ? _lerpCorners(_smoothedCorners!, newCorners, 0.5) 
            : newCorners;

          setState(() {
            _detectedCorners = newCorners;
            _smoothedCorners = smoothed;
          });

          _checkAutoCapture(newCorners);
        }
      } else {
        _consecutiveMisses++;
        _consecutiveDetections = 0;
        if (_consecutiveMisses >= _missThreshold) {
          setState(() { _detectedCorners = null; _smoothedCorners = null; });
          _resetAutoCapture();
        }
      }
    }).catchError((e) {
      debugPrint('Detection error: $e');
    }).whenComplete(() => _isDetecting = false);
  }

  // ═══════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════

  Future<void> _toggleFlash() async {
    if (Platform.isMacOS) return;
    if (_cameraController == null) return;
    final m = _flashMode == FlashMode.off ? FlashMode.torch : _flashMode == FlashMode.torch ? FlashMode.auto : FlashMode.off;
    try { await _cameraController!.setFlashMode(m); setState(() => _flashMode = m); } catch (_) {}
  }

  Future<void> _captureImage() async {
    if (Platform.isMacOS) {
      if (_macOsController == null) return;
      if (_view != _ViewState.camera) return;

      setState(() { _view = _ViewState.processing; _processingMsg = 'Capturing...'; });

      try {
        final photo = await _macOsController!.takePicture();
        if (photo == null || photo.bytes == null) throw Exception('No photo captured');
        
        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }
        final path = '${tempDir.path}/macos_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(path).writeAsBytes(photo.bytes!);

        if (_captureMode == 1) { // Continuous
          _continuousImages.add(path);
          setState(() { _view = _ViewState.camera; });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Page ${_continuousImages.length} captured'), duration: const Duration(milliseconds: 800)));
          return;
        }

        setState(() => _processingMsg = 'Processing...');
        final result = await platform.invokeMethod('processCapture', path);
        final map = Map<String, dynamic>.from(result);

        setState(() {
          _capturedPath = path;
          _correctedPath = map['correctedPath'] as String?;
          _detectedType = map['type'] as String?;
          _view = _ViewState.confirm;
        });
      } catch (e) {
        debugPrint('Capture error: $e');
        setState(() { _view = _ViewState.camera; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_view != _ViewState.camera) return;

    _stopStream();
    await Future.delayed(const Duration(milliseconds: 50));

    setState(() { _view = _ViewState.processing; _processingMsg = 'Capturing...'; });

    try {
      final photo = await _cameraController!.takePicture();

      if (_captureMode == 1) { // Continuous
        _continuousImages.add(photo.path);
        setState(() { _view = _ViewState.camera; });
        _resetAutoCapture();
        _startStream();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Page ${_continuousImages.length} captured'), duration: const Duration(milliseconds: 800)));
        return;
      }

      setState(() => _processingMsg = 'Processing...');
      final result = await platform.invokeMethod('processCapture', photo.path);
      final map = Map<String, dynamic>.from(result);

      setState(() {
        _capturedPath = photo.path;
        _correctedPath = map['correctedPath'] as String?;
        _detectedType = map['type'] as String?;
        _view = _ViewState.confirm;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() { _view = _ViewState.camera; });
      _resetAutoCapture();
      _startStream();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    }
  }

  Future<void> _confirmCapture() async {
    final path = _correctedPath ?? _capturedPath!;
    if (_detectedType == 'card') {
      setState(() { _view = _ViewState.processing; _processingMsg = 'Running OCR...'; });
      await _processOcr(path);
    } else {
      setState(() { _view = _ViewState.processing; _processingMsg = 'Generating PDF...'; });
      await _generatePdf([path]);
    }
  }

  void _retake() {
    setState(() { _view = _ViewState.camera; _capturedPath = null; _correctedPath = null; _detectedType = null;
      _detectedCorners = null; _smoothedCorners = null;
      _consecutiveDetections = 0; _consecutiveMisses = 0; });
    _resetAutoCapture();
    _startStream();
  }

  void _toggleDetectedType() {
    setState(() { _detectedType = _detectedType == 'card' ? 'document' : 'card'; });
  }

  Future<void> _finishContinuous() async {
    if (_continuousImages.isEmpty) return;
    _stopStream();
    setState(() { _view = _ViewState.processing; _processingMsg = 'Generating PDF (${_continuousImages.length} pages)...'; });
    await _generatePdf(List.from(_continuousImages));
  }

  Future<void> _pickFromGallery() async {
    final path = await _scannerService.pickFromGallery();
    if (path == null) return;
    _stopStream();
    setState(() { _view = _ViewState.processing; _processingMsg = 'Analyzing image...'; });
    try {
      final result = await platform.invokeMethod('processCapture', path);
      final map = Map<String, dynamic>.from(result);
      setState(() {
        _capturedPath = path;
        _correctedPath = map['correctedPath'] as String?;
        _detectedType = map['type'] as String?;
        _view = _ViewState.confirm;
      });
    } catch (e) {
      setState(() { _view = _ViewState.camera; });
      _startStream();
    }
  }

  Future<void> _generatePdf(List<String> paths) async {
    try {
      final String pdfPath = await platform.invokeMethod('generatePdf', paths);
      if (mounted) setState(() { _pdfPath = pdfPath; _view = _ViewState.pdfResult; _continuousImages.clear(); });
    } catch (e) {
      if (mounted) { setState(() { _view = _ViewState.camera; }); _startStream();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e'))); }
    }
  }

  Future<void> _processOcr(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final String jsonStr = await platform.invokeMethod('processImage', bytes);
      if (jsonStr.isNotEmpty && jsonStr != 'No text detected') _parseOcrResult(jsonStr);
      else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No text detected — fill in manually')));
    } catch (e) { debugPrint('OCR error: $e'); }
    finally { if (mounted) setState(() => _view = _ViewState.cardReview); }
  }

  void _parseOcrResult(String jsonStr) {
    try {
      final List<dynamic> data = jsonDecode(jsonStr);
      _ocrBlocks = data.map((item) {
        final r = item['rect'];
        return OcrBlock(
          item['text'] as String,
          Rect.fromLTWH(r['x'], r['y'], r['w'], r['h'])
        );
      }).toList();
      
      _name = ''; _company = ''; _email = ''; _mobile = ''; _tel = ''; _website = ''; _address = ''; _title = '';
      
      for (var block in _ocrBlocks) {
        final line = block.text.trim();
        if (line.isEmpty) continue;
        
        // Email
        if (line.contains('@') && line.contains('.')) {
          _email = line; continue;
        }
        
        // Phone/Mobile/Fax
        final digitCount = line.replaceAll(RegExp(r'\D'), '').length;
        if (digitCount >= 8 && digitCount <= 18 && RegExp(r'^[\+\d\s\(\)\-x]+$').hasMatch(line)) {
          final llower = line.toLowerCase();
          if (llower.contains('m') || llower.contains('mobile') || llower.contains('cell') || llower.contains('手')) {
            _mobile = line.replaceAll(RegExp(r'[A-Za-z:\s手帯机电]+'), '').trim();
          } else if (!llower.contains('f') && !llower.contains('fax') && !llower.contains('传')) {
            _tel = line.replaceAll(RegExp(r'[A-Za-z:\s电話话]+'), '').trim();
          }
          continue;
        }
        
        // Website
        final lurl = line.toLowerCase();
        if (lurl.startsWith('www') || lurl.startsWith('http') || (lurl.contains('.com') && !lurl.contains('@'))) {
          _website = line; continue;
        }
        
        // Company
        if (line.contains('公司') || line.contains('株式会社') || line.contains('Group') || line.contains('Inc') || line.contains('LLC') || line.contains('Ltd') || line.contains('Co.,')) {
          _company = line; continue;
        }
        
        // Skip dept
        if (line.contains('部') || line.contains('室') || line.contains('課') || line.contains('Division') || line.contains('Dept')) continue;
        
        // Title
        if (line.contains('经理') || line.contains('总监') || line.contains('代表') || line.contains('Director') || line.contains('Manager') || line.contains('CEO') || line.contains('President') || line.contains('Engineer') || line.contains('主管') || line.contains('役') || line.contains('長')) {
          _title = line; continue;
        }
        
        // Address
        if (line.contains('市') || line.contains('区') || line.contains('省') || line.contains('县') || line.contains('町') || line.contains('丁目') || line.contains('Street') || line.contains('Avenue') || line.contains('Road') || line.contains('Floor') || line.contains('Room') || line.contains('Bldg')) {
          _address = _address.isEmpty ? line : '$_address $line'; continue;
        }
        
        // Name fallback
        if (_name.isEmpty && !line.contains(RegExp(r'\d')) && line.length < 15) {
          _name = line;
        }
      }
    } catch (e) {
      debugPrint('JSON parse error: $e');
      // Fallback if it wasn't valid JSON
      final lines = jsonStr.split('\n').where((l) => l.trim().isNotEmpty).toList();
      _name = ''; _company = ''; _email = ''; _mobile = ''; _tel = ''; _website = ''; _address = ''; _title = '';
      for (var line in lines) {
        if (line.contains('@')) { _email = line; }
        else if (RegExp(r'\d{8,}').hasMatch(line)) { _mobile.isEmpty ? _mobile = line : _tel = line; }
        else if (line.toLowerCase().startsWith('www') || line.toLowerCase().startsWith('http')) { _website = line; }
        else if (_name.isEmpty && !line.contains(RegExp(r'\d'))) { _name = line; }
        else if (_company.isEmpty) { _company = line; }
        else if (_address.isEmpty && line.length > 10) { _address = line; }
      }
    }
  }

  void _saveCard() { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card Saved!'))); Navigator.pop(context); }
  void _sharePdf() { if (_pdfPath != null) Share.shareXFiles([XFile(_pdfPath!)], text: 'Scanned Document'); }
  void _resetToCamera() { setState(() { _capturedPath = null; _correctedPath = null; _pdfPath = null; _detectedType = null; _view = _ViewState.camera; _continuousImages.clear(); _ocrBlocks.clear();
    _detectedCorners = null; _smoothedCorners = null; _consecutiveDetections = 0; _consecutiveMisses = 0; }); _resetAutoCapture(); _startStream(); }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_view == _ViewState.camera) {
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            if (_captureMode == 0) setState(() => _captureMode = 1);
          } else if (details.primaryVelocity! > 0) {
            if (_captureMode == 1) setState(() { _captureMode = 0; _continuousImages.clear(); });
          }
        },
        child: _buildCamera(),
      );
    }

    switch (_view) {
      case _ViewState.processing: return _buildProcessing();
      case _ViewState.confirm: return _buildConfirm();
      case _ViewState.cardReview: return _buildCardReview();
      case _ViewState.pdfResult: return _buildPdfResult();
      default: return Container();
    }
  }

  // ─── Camera ──────────────────────────────────────
  Widget _buildCameraPreview() {
    if (Platform.isMacOS) {
      return Positioned.fill(
        child: CameraMacOSView(
          key: _macOsCameraKey,
          fit: BoxFit.cover,
          cameraMode: CameraMacOSMode.photo,
          onCameraInizialized: (CameraMacOSController controller) {
            setState(() {
              _macOsController = controller;
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _startStream();
            });
          },
          onCameraDestroyed: () {
            return const SizedBox.shrink();
          },
          enableAudio: false,
        ),
      );
    }

    final ps = _cameraController!.value.previewSize;
    // Ensure portrait orientation: width = smaller, height = larger
    final w = ps != null ? (ps.width > ps.height ? ps.height : ps.width) : 1.0;
    final h = ps != null ? (ps.width > ps.height ? ps.width : ps.height) : 1.0;
    return Positioned.fill(child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge,
      child: SizedBox(width: w, height: h, child: CameraPreview(_cameraController!))));
  }

  Widget _buildCamera() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (Platform.isMacOS) ...[
          if (_macOsCameraStarted)
            _buildCameraPreview()
          else
            _buildCameraError(),
            
          // Base UI elements that don't depend on actual camera readiness
          if (_macOsCameraStarted) ...[
            _smoothedCorners != null ? _buildDetectedOverlay() : _buildStaticFrame(),
            _buildGuideText(),
          ],
          _buildTopBar(),
          _buildBottomControls(),
          _buildModeSelector(),
        ] else ...[
          if (_isCameraReady && _cameraController != null)
            _buildCameraPreview()
          else if (_isCameraError)
            _buildCameraError()
          else
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.white), SizedBox(height: 16),
              Text('Loading Camera...', style: TextStyle(color: Colors.white70, fontSize: 14))
            ])),
            
          if (_isCameraReady) ...[
            _smoothedCorners != null ? _buildDetectedOverlay() : _buildStaticFrame(),
            _buildGuideText(),
            if (_stableStartTime != null && _smoothedCorners != null) _buildAutoCaptureIndicator(),
            _buildTopBar(),
            _buildBottomControls(),
            _buildModeSelector(),
          ],
        ]
      ]),
    );
  }

  // ─── Top Bar ─────────────────────────────────────
  Widget _buildTopBar() {
    return Positioned(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _circleBtn(Icons.close, () => Navigator.pop(context)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_smoothedCorners != null ? '🔵 ' : '✨ ', style: const TextStyle(fontSize: 14)),
            Text(_smoothedCorners != null ? 'Detected' : 'Auto-Detect',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ])),
        _circleBtn(Icons.help_outline, () => showDialog(context: context,
          builder: (ctx) => AlertDialog(title: const Text('Tips'),
            content: const Text('• Hold steady to auto-capture\n• Swipe left/right to change mode\n• Tap shutter manually anytime\n• Correct card/document type after capture'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))]))),
      ]));
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(width: 40, height: 40,
      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22)));
  }

  // ─── Static Frame ─────────────────────────────────
  Widget _buildStaticFrame() {
    return AnimatedBuilder(animation: _frameGlowAnim, builder: (context, _) {
      final g = _frameGlowAnim.value;
      const color = Color(0xFF007AFF);
      final sw = MediaQuery.of(context).size.width;
      final sh = MediaQuery.of(context).size.height;
      final topPad = MediaQuery.of(context).padding.top;
      final frameW = sw * 0.80;
      final frameH = frameW * 1.4;
      final bottomControlsTop = sh - MediaQuery.of(context).padding.bottom - 180;
      final topBarBottom = topPad + 60;
      final availableH = bottomControlsTop - topBarBottom - 40;
      final actualH = frameH > availableH ? availableH : frameH;
      final centerY = topBarBottom + (bottomControlsTop - topBarBottom) / 2;
      final frameTop = centerY - actualH / 2;

      return Positioned(top: frameTop, left: (sw - frameW) / 2, width: frameW, height: actualH,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: g), width: 2.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: g * 0.3), blurRadius: 20, spreadRadius: 2)]),
          child: Stack(children: [
            _corner(Alignment.topLeft, color, g), _corner(Alignment.topRight, color, g),
            _corner(Alignment.bottomLeft, color, g), _corner(Alignment.bottomRight, color, g),
          ])));
    });
  }

  // ─── Detected Overlay (smooth blue polygon) ───
  Widget _buildDetectedOverlay() {
    final corners = _smoothedCorners!;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Determine the portrait-oriented preview dimensions
    // Vision returns normalized coords (0-1) in the "upright" (portrait) space
    // We need to compute how the preview maps to the screen
    double portraitW, portraitH;
    
    final rawW = _cameraController!.value.previewSize?.width ?? screenW;
    final rawH = _cameraController!.value.previewSize?.height ?? screenH;
    
    // Ensure portrait orientation: width should be smaller dimension
    if (rawW > rawH) {
      // previewSize in landscape format — swap for portrait
      portraitW = rawH;
      portraitH = rawW;
    } else {
      // previewSize already in portrait format
      portraitW = rawW;
      portraitH = rawH;
    }
    
    // BoxFit.cover scaling: scale to fill the screen, clip overflow
    final scaleX = screenW / portraitW;
    final scaleY = screenH / portraitH;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final dw = portraitW * scale;
    final dh = portraitH * scale;
    final ox = (dw - screenW) / 2;
    final oy = (dh - screenH) / 2;

    // Vision normalized coordinates: (0,0)=bottom-left, (1,1)=top-right of upright image
    // Screen coordinates: (0,0)=top-left, (screenW,screenH)=bottom-right
    Offset map(double vx, double vy) => Offset(vx * dw - ox, (1 - vy) * dh - oy);

    final tl = map(corners['topLeftX']!, corners['topLeftY']!);
    final tr = map(corners['topRightX']!, corners['topRightY']!);
    final bl = map(corners['bottomLeftX']!, corners['bottomLeftY']!);
    final br = map(corners['bottomRightX']!, corners['bottomRightY']!);

    // Glow brighter when stable (auto-capture approaching)
    final isStable = _stableStartTime != null;
    final baseOpacity = isStable ? 1.0 : _frameGlowAnim.value;
    final strokeColor = isStable ? const Color(0xFF34C759) : const Color(0xFF007AFF); // Green when stable

    return Positioned.fill(child: CustomPaint(
      painter: _DetectedRectPainter(tl: tl, tr: tr, bl: bl, br: br, opacity: baseOpacity, color: strokeColor)));
  }

  // ─── Auto-capture progress indicator ──────────────
  Widget _buildAutoCaptureIndicator() {
    return Positioned(left: 0, right: 0, top: MediaQuery.of(context).padding.top + 100,
      child: Center(child: AnimatedBuilder(
        animation: _autoCaptureAnimController,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  value: _autoCaptureAnimController.value,
                  strokeWidth: 2.5,
                  color: Colors.white,
                  backgroundColor: Colors.white30,
                )),
              const SizedBox(width: 10),
              const Text('Hold Steady...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          );
        },
      )),
    );
  }

  Widget _corner(Alignment a, Color c, double o) {
    const s = 24.0;
    final isTop = a == Alignment.topLeft || a == Alignment.topRight;
    final isLeft = a == Alignment.topLeft || a == Alignment.bottomLeft;
    return Positioned(top: isTop ? 0 : null, bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null, right: !isLeft ? 0 : null,
      child: SizedBox(width: s, height: s, child: CustomPaint(
        painter: _CornerPainter(color: c.withValues(alpha: o), thickness: 3.5, isTop: isTop, isLeft: isLeft))));
  }

  // ─── Guide Text ──────────────────────────────────
  Widget _buildGuideText() {
    final topPad = MediaQuery.of(context).padding.top;
    final guideTop = topPad + 60 + 8;
    String text;
    Color bgColor;
    if (_stableStartTime != null && _smoothedCorners != null) {
      text = '✅ Hold steady — auto-capturing...';
      bgColor = const Color(0xFF34C759);
    } else if (_smoothedCorners != null) {
      text = 'Aligned — Hold steady or tap shutter';
      bgColor = const Color(0xFF007AFF);
    } else {
      text = 'Align card or document';
      bgColor = const Color(0xFF007AFF);
    }

    return Positioned(top: guideTop, left: 0, right: 0,
      child: Center(child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)))));
  }

  // ─── Bottom Controls ─────────────────────────────
  Widget _buildBottomControls() {
    return Positioned(left: 0, right: 0, bottom: MediaQuery.of(context).padding.bottom + 80,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ctrlBtn(icon: _flashMode == FlashMode.off ? Icons.flash_off : _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_auto, label: 'FLASH', onTap: _toggleFlash),
        GestureDetector(onTap: _captureImage, child: Container(width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
          child: Container(margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF007AFF)),
            child: Icon(_captureMode == 1 ? Icons.burst_mode : Icons.camera_alt, color: Colors.white, size: 28)))),
        _captureMode == 1 && _continuousImages.isNotEmpty
          ? _ctrlBtn(icon: Icons.check_circle, label: 'DONE (${_continuousImages.length})', onTap: _finishContinuous)
          : _ctrlBtn(icon: Icons.photo_library, label: 'GALLERY', onTap: _pickFromGallery),
      ]));
  }

  Widget _ctrlBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24)),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    ]));
  }

  // ─── Mode Selector ───────────────────────────────
  Widget _buildModeSelector() {
    return Positioned(left: 0, right: 0, bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _modeTab('SINGLE', 0, Icons.crop_original),
        const SizedBox(width: 20),
        const Icon(Icons.swipe, color: Colors.white24, size: 16),
        const SizedBox(width: 20),
        _modeTab('CONTINUOUS', 1, Icons.burst_mode),
      ]));
  }

  Widget _modeTab(String label, int mode, IconData icon) {
    final sel = _captureMode == mode;
    return GestureDetector(onTap: () { if (_captureMode != mode) setState(() { _captureMode = mode; _continuousImages.clear(); }); },
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF007AFF).withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF007AFF) : Colors.white24, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: sel ? const Color(0xFF007AFF) : Colors.white54),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: sel ? const Color(0xFF007AFF) : Colors.white54,
            fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, letterSpacing: 0.5)),
        ])));
  }

  // ─── Processing ──────────────────────────────────
  Widget _buildProcessing() {
    return Scaffold(backgroundColor: Colors.black,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 16),
        Text(_processingMsg, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ])));
  }

  // ─── Confirmation Screen ─────────────────────────
  Widget _buildConfirm() {
    final isCard = _detectedType == 'card';
    final imagePath = _correctedPath ?? _capturedPath!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(title: Text(isCard ? 'Business Card Detected' : 'Document Detected'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: Column(children: [
        const SizedBox(height: 16),
        // Type Switcher
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _typeOption('Business Card', true, isCard),
              _typeOption('Document', false, !isCard),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Preview
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () => _showFullScreenPreview(imagePath),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(16),
                child: Image.file(File(imagePath), fit: BoxFit.contain)))))),
        const SizedBox(height: 24),
        // Buttons
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _confirmCapture,
              icon: const Icon(Icons.check),
              label: Text(isCard ? 'Extract Text' : 'Save as PDF'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _retake,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                foregroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ])),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
      ]),
    );
  }

  void _showFullScreenPreview(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenImageViewer(imagePath: path),
    ));
  }

  Widget _typeOption(String label, bool isCardType, bool isSelected) {
    return GestureDetector(
      onTap: () { if (!isSelected) _toggleDetectedType(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.black : Colors.grey)),
      ),
    );
  }

  // ─── Camera Error ────────────────────────────────
  Widget _buildCameraError() {
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)),
          child: Icon(Platform.isMacOS ? Icons.desktop_mac : (_permissionDenied ? Icons.no_photography : Icons.camera_alt), size: 40, color: const Color(0xFFE65100))),
        const SizedBox(height: 24),
        Text(Platform.isMacOS ? 'macOS Camera Setup' : (_permissionDenied ? 'Camera Access Required' : 'Camera Unavailable'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Text(Platform.isMacOS 
            ? 'Click below to authorize and start the macOS camera.' 
            : (_permissionPermanentlyDenied ? 'Please enable camera in Settings.' : 'Unable to access camera.'),
          style: const TextStyle(fontSize: 14, color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        if (Platform.isMacOS) ...[
          SizedBox(width: 280, child: ElevatedButton.icon(onPressed: _initCameraMacos,
            icon: const Icon(Icons.videocam), label: const Text('Authorize & Start Camera'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF34C759), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(height: 12),
        ],
        if (!Platform.isMacOS && _permissionPermanentlyDenied) ...[
          SizedBox(width: 220, child: ElevatedButton.icon(onPressed: () => _scannerService.openSettings(),
            icon: const Icon(Icons.settings), label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(height: 12),
        ],
        SizedBox(width: 220, child: OutlinedButton.icon(onPressed: () { setState(() { _isCameraError = false; _initCamera(); }); },
          icon: const Icon(Icons.refresh), label: const Text('Retry'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.white54), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(height: 12),
        SizedBox(width: 280, child: ElevatedButton.icon(onPressed: _pickFromGallery,
          icon: const Icon(Icons.photo_library), label: const Text('Pick from Gallery (Test OCR)'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ])));
  }

  // ─── PDF Result ──────────────────────────────────
  Widget _buildPdfResult() {
    return Scaffold(appBar: AppBar(title: const Text('Document Scanned'),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: Center(child: Padding(padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.picture_as_pdf, size: 40, color: Color(0xFF4CAF50))),
          const SizedBox(height: 24),
          const Text('PDF Created Successfully', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_pdfPath!.split('/').last, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _sharePdf,
            icon: const Icon(Icons.share), label: const Text('Share PDF'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _resetToCamera, icon: const Icon(Icons.refresh), label: const Text('Scan Another')),
        ]))));
  }

  // ─── Card Review ─────────────────────────────────
  Widget _buildCardReview() {
    final imagePath = _correctedPath ?? _capturedPath!;
    return Scaffold(appBar: AppBar(title: const Text('Review Card'),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _resetToCamera)]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        // Card preview
        GestureDetector(
          onTap: () => _showFullScreenPreview(imagePath),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.file(File(imagePath)),
                  if (_ocrBlocks.isNotEmpty)
                    Positioned.fill(child: CustomPaint(painter: OcrHighlightPainter(_ocrBlocks))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)]),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _field('Name', _name, (v) => _name = v),
            _field('Company', _company, (v) => _company = v),
            _field('Title', _title, (v) => _title = v),
            _field('Mobile', _mobile, (v) => _mobile = v, kb: TextInputType.phone),
            _field('TEL', _tel, (v) => _tel = v, kb: TextInputType.phone),
            _field('Email', _email, (v) => _email = v, kb: TextInputType.emailAddress),
            _field('Website', _website, (v) => _website = v, kb: TextInputType.url),
            _field('Address', _address, (v) => _address = v),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _saveCard,
              icon: const Icon(Icons.check), label: const Text('Save Contact'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ])),
      ])));
  }

  Widget _field(String label, String val, Function(String) cb, {TextInputType kb = TextInputType.text}) {
    return Padding(padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(initialValue: val, onChanged: cb, keyboardType: kb,
        decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))));
  }
}

// ═══════════════════════════════════════════════════
//  Full Screen Image Viewer
// ═══════════════════════════════════════════════════

class _FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const _FullScreenImageViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Preview')),
      body: Center(
        child: InteractiveViewer(minScale: 0.5, maxScale: 4.0,
          child: Image.file(File(imagePath), fit: BoxFit.contain)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Custom Painters
// ═══════════════════════════════════════════════════

class _DetectedRectPainter extends CustomPainter {
  final Offset tl, tr, bl, br;
  final double opacity;
  final Color color;
  _DetectedRectPainter({required this.tl, required this.tr, required this.bl, required this.br, required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 3.0 ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(tl.dx, tl.dy)..lineTo(tr.dx, tr.dy)..lineTo(br.dx, br.dy)..lineTo(bl.dx, bl.dy)..close();
    canvas.drawPath(path, paint);

    // Semi-transparent fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final dotPaint = Paint()..color = color.withValues(alpha: opacity)..style = PaintingStyle.fill;
    for (final p in [tl, tr, bl, br]) { canvas.drawCircle(p, 6, dotPaint); }
  }

  @override
  bool shouldRepaint(covariant _DetectedRectPainter old) =>
    tl != old.tl || tr != old.tr || bl != old.bl || br != old.br || opacity != old.opacity || color != old.color;
}

class _CornerPainter extends CustomPainter {
  final Color color; final double thickness; final bool isTop; final bool isLeft;
  _CornerPainter({required this.color, required this.thickness, required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thickness..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    if (isTop && isLeft) { path.moveTo(0, size.height); path.lineTo(0, 6); path.quadraticBezierTo(0, 0, 6, 0); path.lineTo(size.width, 0); }
    else if (isTop && !isLeft) { path.moveTo(0, 0); path.lineTo(size.width - 6, 0); path.quadraticBezierTo(size.width, 0, size.width, 6); path.lineTo(size.width, size.height); }
    else if (!isTop && isLeft) { path.moveTo(0, 0); path.lineTo(0, size.height - 6); path.quadraticBezierTo(0, size.height, 6, size.height); path.lineTo(size.width, size.height); }
    else { path.moveTo(size.width, 0); path.lineTo(size.width, size.height - 6); path.quadraticBezierTo(size.width, size.height, size.width - 6, size.height); path.lineTo(0, size.height); }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => color != old.color || thickness != old.thickness;
}

class OcrBlock {
  final String text;
  final Rect rect;
  OcrBlock(this.text, this.rect);
}

class OcrHighlightPainter extends CustomPainter {
  final List<OcrBlock> blocks;
  OcrHighlightPainter(this.blocks);

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var b in blocks) {
      // Vision bounds are normalized [0, 1] with origin at bottom-left
      final flippedY = 1.0 - (b.rect.top + b.rect.height);
      final drawRect = Rect.fromLTWH(
        b.rect.left * size.width,
        flippedY * size.height,
        b.rect.width * size.width,
        b.rect.height * size.height
      );
      canvas.drawRect(drawRect, fillPaint);
      canvas.drawRect(drawRect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant OcrHighlightPainter oldDelegate) => true;
}
