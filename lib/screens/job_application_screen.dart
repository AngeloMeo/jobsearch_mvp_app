import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/ui_helpers.dart';

/// Form di candidatura (Scenario S2 - Requisito R6).
/// Valida Nome, Cognome, Email, seleziona un CV PDF e invia con MultipartRequest.
class JobApplicationScreen extends StatefulWidget {
  final Job job;

  const JobApplicationScreen({
    super.key,
    required this.job,
  });

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _emailController = TextEditingController();

  PlatformFile? _selectedCv;
  String? _cvError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Apre il selettore file nativo di Android filtrando solo file .pdf.
  Future<void> _pickPdfCv() async {
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Seleziona il tuo CV in PDF',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (picked == null) return;

      final ext = picked.extension?.toLowerCase();
      if (ext != 'pdf' && !picked.name.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        setState(() {
          _cvError = 'Seleziona un file in formato PDF (.pdf).';
        });
        showErrorSnackBar(context, 'Il file selezionato deve essere un PDF.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedCv = picked;
        _cvError = null;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Errore nella selezione del file: $e');
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'PDF selezionato';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _submitApplication() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (_selectedCv == null) {
      setState(() {
        _cvError = 'Allega il tuo CV in formato PDF per continuare.';
      });
    }
    if (!formValid || _selectedCv == null) {
      if (_selectedCv == null) {
        showErrorSnackBar(context, 'Allega il tuo CV in formato PDF.');
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final application = await ApiService.instance.applyToJob(
        jobId: widget.job.id,
        nome: _nomeController.text,
        cognome: _cognomeController.text,
        email: _emailController.text,
        cvFile: _selectedCv!,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF15803D),
              size: 48,
            ),
            title: const Text('Candidatura inviata!'),
            content: Text(
              'Grazie ${application.fullName}, la tua candidatura per "${widget.job.titolo}" presso ${widget.job.nomeAzienda} è stata registrata con successo.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Torna alla bacheca'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      showErrorSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      showErrorSnackBar(context, 'Errore durante l\'invio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invia Candidatura'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job.titolo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.job.nomeAzienda,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nomeController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci il tuo nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cognomeController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Cognome *',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci il tuo cognome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'nome@esempio.it',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci la tua email';
                  }
                  if (!isValidEmailFormat(value)) {
                    return 'Inserisci un indirizzo email valido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Curriculum Vitae (PDF) *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickPdfCv,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  _selectedCv == null
                      ? 'Allega CV (PDF)'
                      : 'Cambia CV selezionato',
                ),
              ),
              if (_selectedCv != null) ...[
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      _selectedCv!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatFileSize(_selectedCv!.lengthSync()),
                    ),
                    trailing: IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _selectedCv = null;
                              });
                            },
                      icon: const Icon(Icons.close),
                      tooltip: 'Rimuovi allegato',
                    ),
                  ),
                ),
              ],
              if (_cvError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _cvError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isSubmitting ? 'Invio in corso...' : 'Conferma e Invia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
