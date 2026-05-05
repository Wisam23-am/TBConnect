import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'patient_register_screen.dart';

class PatientQrScreen extends StatelessWidget {
  const PatientQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _PatientQrForm(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientQrForm extends StatefulWidget {
  @override
  State<_PatientQrForm> createState() => _PatientQrFormState();
}

class _PatientQrFormState extends State<_PatientQrForm> {
  final _qrCodeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _qrCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Position the QR code provided by your clinic within the frame to link your profile.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF43474E),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF273645), Color(0xFF111922)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 24, 51, 0.1),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  if (_isScanned) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final barcode = barcodes.first;
                    if (barcode.rawValue != null) {
                      setState(() {
                        _isScanned = true;
                        _qrCodeController.text = barcode.rawValue!;
                      });
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute<void>(
                          builder: (_) => PatientRegisterScreen(
                              qrCode: barcode.rawValue!),
                        ),
                      )
                          .then((_) {
                        if (mounted) {
                          setState(() {
                            _isScanned = false;
                          });
                        }
                      });
                    }
                  }
                },
              ),
              Center(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFAFC8F1).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 16,
                          color: Color(0xFF2A609C),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF191C1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _qrCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Kode Aktivasi / QR Code',
            hintText: 'Contoh: TBC-8AB3F',
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PatientRegisterScreen(
                    qrCode: _qrCodeController.text.trim()),
              ),
            );
          },
          icon: const Icon(Icons.keyboard_rounded),
          label: const Text('INPUT MANUAL CODE'),
        ),
      ],
    );
  }
}
