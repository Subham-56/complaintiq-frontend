import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.onSubmitted});

  /// Called after a complaint is successfully submitted (whether it was
  /// accepted as Pending or flagged Under Review) — lets the parent shell
  /// switch to the "My Complaints" tab so the citizen sees it right away.
  final VoidCallback? onSubmitted;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  double? _latitude;
  double? _longitude;

  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasImage =>
      kIsWeb ? _selectedImageBytes != null : _selectedImageFile != null;

  Future<void> _pickImageMobile(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null && mounted) {
      setState(() => _selectedImageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickImageWeb() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null && mounted) {
      setState(() {
        _selectedImageBytes = result.files.single.bytes;
        _selectedImageName = result.files.single.name;
      });
    }
  }

  void _showImageSourceSheet() {
    if (kIsWeb) {
      _pickImageWeb();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.primary,
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageMobile(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primary,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageMobile(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack("Enable location services");
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showSnack("Location permission denied");
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack("Location permission permanently denied");
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showSnack("Please enter a description");
      return;
    }
    if (!_hasImage) {
      _showSnack("Please add an image");
      return;
    }
    if (_latitude == null || _longitude == null) {
      _showSnack("Please get location first");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.submitComplaint(
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        imageFile: kIsWeb ? null : _selectedImageFile,
        imageBytes: kIsWeb ? _selectedImageBytes : null,
        imageName: kIsWeb ? _selectedImageName : null,
      );

      if (!mounted) return;

      final message = result['message']?.toString() ?? "Complaint submitted";

      _showSnack(message);

      // The complaint was successfully created either way (whether it
      // landed as Pending or got flagged Under Review) — clear the form
      // and hand off to the parent shell to switch to "My Complaints"
      // so the citizen sees what they just submitted right away.
      setState(() {
        _descriptionController.clear();
        _selectedImageFile = null;
        _selectedImageBytes = null;
        _selectedImageName = null;
        _latitude = null;
        _longitude = null;
      });

      widget.onSubmitted?.call();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 700 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report an Issue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Our AI reads your photo and description to categorize, assess urgency, and verify authenticity',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),

              const Text(
                'Description',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Describe the issue in detail...',
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Photo Evidence',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isSubmitting ? null : _showImageSourceSheet,
                child: Container(
                  width: double.infinity,
                  height: _hasImage ? 220 : 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.border,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: kIsWeb
                              ? Image.memory(
                                  _selectedImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  _selectedImageFile!,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              kIsWeb
                                  ? Icons.upload_file_rounded
                                  : Icons.camera_alt_outlined,
                              size: 32,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              kIsWeb
                                  ? 'Click to upload a photo'
                                  : 'Tap to capture or upload',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Location',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: _latitude != null
                          ? AppTheme.statusResolved
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isFetchingLocation
                            ? 'Fetching your location...'
                            : _latitude != null
                            ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : 'Location not set',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isFetchingLocation ? null : _getLocation,
                      child: Text(
                        _isFetchingLocation ? 'Fetching...' : 'Get Location',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Complaint'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}