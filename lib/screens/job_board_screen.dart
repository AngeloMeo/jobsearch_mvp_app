import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/auth_session.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/ui_helpers.dart';
import 'auth_screen.dart';
import 'company_area_screen.dart';
import 'job_detail_screen.dart';

/// Schermata iniziale pubblica (Bacheca - Scenario S2 / Requisito R5).
/// Accessibile senza login: mostra GET /jobs e il tasto per l'Area Aziende.
class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  final ApiService _apiService = ApiService.instance;

  List<Job> _jobs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJobs(); // Carica subito gli annunci pubblici all'apertura.
  }

  Future<void> _loadJobs({bool showErrorBanner = true}) async {
    setState(() {
      if (_jobs.isEmpty) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final jobs = await _apiService.fetchPublicJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      if (showErrorBanner) {
        showErrorSnackBar(context, e.message);
      }
    } catch (e) {
      if (!mounted) return;
      final message = 'Errore imprevisto: $e';
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      if (showErrorBanner) {
        showErrorSnackBar(context, message);
      }
    }
  }

  Future<void> _openIpSettings() async {
    final updated = await showServerIpDialog(context);
    if (updated && mounted) {
      await _loadJobs();
    }
  }

  Future<void> _openCompanySection(AuthSession? session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            session != null ? const CompanyAreaScreen() : const AuthScreen(),
      ),
    );
    if (mounted) {
      await _loadJobs(showErrorBanner: false);
    }
  }

  Future<void> _openJobDetail(Job job) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(job: job),
      ),
    );
    if (mounted) {
      await _loadJobs(showErrorBanner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bacheca Lavoro'),
        actions: [
          IconButton(
            onPressed: _openIpSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Impostazioni IP',
          ),
          ValueListenableBuilder<AuthSession?>(
            valueListenable: _apiService.sessionNotifier,
            builder: (context, session, _) {
              final isLoggedIn = session != null;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton.tonalIcon(
                  onPressed: () => _openCompanySection(session),
                  icon: Icon(
                    isLoggedIn
                        ? Icons.business_center_outlined
                        : Icons.login_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isLoggedIn ? 'Area Riservata' : 'Area Aziende / Login',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Server: ${ApiConfig.currentBaseUrl}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_jobs.length} annunci',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadJobs,
              child: _buildBody(colorScheme),
            ),
          ),
        ],
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
            Text('Caricamento annunci in corso...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _jobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.cloud_off_rounded, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Connessione non riuscita',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _openIpSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Cambia IP'),
                ),
                FilledButton.icon(
                  onPressed: _loadJobs,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_jobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.work_off_outlined,
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
            'Trascina verso il basso per aggiornare o accedi come azienda per pubblicare un nuovo annuncio.',
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
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return _JobBoardCard(
          job: job,
          onTap: () => _openJobDetail(job),
        );
      },
    );
  }
}

class _JobBoardCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const _JobBoardCard({
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          size: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          job.nomeAzienda,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.titolo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                job.descrizione,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
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
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
