import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/ui_helpers.dart';
import 'job_applications_screen.dart';
import 'job_board_screen.dart';

/// Area Riservata Azienda (Scenari S1 & S3 - Requisiti R3, R4, R7).
/// Mostra gli annunci dell'azienda, permette di crearne di nuovi e di fare Logout.
class CompanyAreaScreen extends StatefulWidget {
  const CompanyAreaScreen({super.key});

  @override
  State<CompanyAreaScreen> createState() => _CompanyAreaScreenState();
}

class _CompanyAreaScreenState extends State<CompanyAreaScreen> {
  final ApiService _apiService = ApiService.instance;

  List<Job> _companyJobs = [];
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompanyJobs();
  }

  Future<void> _loadCompanyJobs() async {
    setState(() {
      if (_companyJobs.isEmpty) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final jobs = await _apiService.fetchCompanyJobs();
      if (!mounted) return;
      setState(() {
        _companyJobs = jobs;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        await _apiService.clearLocalSession();
        if (!mounted) return;
        showErrorSnackBar(context, 'Sessione scaduta. Effettua di nuovo il login.');
        _navigateToPublicBoardClearingStack();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      showErrorSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      final message = 'Errore imprevisto: $e';
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
    }
  }

  /// Azzera lo stack di navigazione così il tasto Indietro non può riaprire l'Area Riservata.
  void _navigateToPublicBoardClearingStack() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JobBoardScreen()),
      (route) => false,
    );
  }

  /// Invoca POST /auth/logout, cancella il token da SharedPreferences e torna in bacheca.
  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _apiService.logoutCompany();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Logout effettuato con successo.');
      _navigateToPublicBoardClearingStack();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
      _navigateToPublicBoardClearingStack();
    } catch (_) {
      if (!mounted) return;
      _navigateToPublicBoardClearingStack();
    }
  }

  Future<void> _openCreateJobSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateJobBottomSheet(),
    );

    if (created == true && mounted) {
      await _loadCompanyJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final companyName = _apiService.currentSession?.nomeAzienda ?? 'Azienda';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Riservata'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isLoggingOut ? null : _handleLogout,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              icon: _isLoggingOut
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.error,
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.apartment_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_companyJobs.length} annunci pubblicati • Tocca per vedere le candidature',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCompanyJobs,
              child: _buildBody(colorScheme),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateJobSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo Annuncio'),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento annunci aziendali...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _companyJobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off_rounded, size: 60, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _loadCompanyJobs,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ),
        ],
      );
    }

    if (_companyJobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.post_add_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun annuncio pubblicato',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Premi il pulsante "+" in basso per pubblicare il tuo primo annuncio di lavoro.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _companyJobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = _companyJobs[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobApplicationsScreen(job: job),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.titolo,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.descrizione,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        job.formattedDate,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        'Vedi candidature',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreateJobBottomSheet extends StatefulWidget {
  const _CreateJobBottomSheet();

  @override
  State<_CreateJobBottomSheet> createState() => _CreateJobBottomSheetState();
}

class _CreateJobBottomSheetState extends State<_CreateJobBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _publishJob() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ApiService.instance.createJob(
        titolo: _titleController.text,
        descrizione: _descriptionController.text,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Annuncio pubblicato con successo!');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      showErrorSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      showErrorSnackBar(context, 'Errore durante la pubblicazione: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.work_outline_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nuovo Annuncio di Lavoro',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titolo posizione *',
                  hintText: 'es. Sviluppatore Flutter Junior',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci il titolo dell\'annuncio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                maxLines: 5,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrizione *',
                  hintText: 'Descrivi requisiti, responsabilità, sede e modalità di lavoro...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci la descrizione dell\'annuncio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _publishJob,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: Text(
                    _isSaving ? 'Pubblicazione...' : 'Pubblica Annuncio',
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
