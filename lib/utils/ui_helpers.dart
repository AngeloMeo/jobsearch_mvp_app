import 'package:flutter/material.dart';

import '../config/api_config.dart';

void showErrorSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
}

void showSuccessSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

bool isValidEmailFormat(String value) {
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return emailRegex.hasMatch(value.trim());
}

Future<bool> showServerIpDialog(BuildContext context) async {
  final controller = TextEditingController(text: ApiConfig.currentBaseUrl);
  final formKey = GlobalKey<FormState>();
  bool changed = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet),
            SizedBox(width: 10),
            Expanded(child: Text('Impostazioni IP Server')),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inserisci l\'indirizzo IP del computer su cui è avviato il server REST (porta 8080).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Indirizzo IP o URL server',
                  hintText: 'es. 192.168.1.45 o http://192.168.1.45:8080',
                  prefixIcon: Icon(Icons.lan_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci un indirizzo IP o URL';
                  }
                  try {
                    ApiConfig.normalizeServerUrl(value);
                    return null;
                  } on FormatException catch (e) {
                    return e.message;
                  }
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Emulatore (10.0.2.2)'),
                    onPressed: () {
                      controller.text = 'http://10.0.2.2:8080';
                    },
                  ),
                  ActionChip(
                    label: const Text('Default'),
                    onPressed: () {
                      controller.text = ApiConfig.baseUrl;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final savedUrl = await ApiConfig.saveServerAddress(controller.text);
              changed = true;
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                showSuccessSnackBar(context, 'Server impostato su $savedUrl');
              }
            },
            child: const Text('Salva'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return changed;
}
