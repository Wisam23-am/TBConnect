import 'package:flutter/material.dart';

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

  @override
  void dispose() {
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
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFAFC8F1),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 72,
                    color: Color(0xFFD3E3FF),
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
