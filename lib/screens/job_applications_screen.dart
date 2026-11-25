import 'package:flutter/material.dart';

import '../models/job.dart';
import '../models/job_application.dart';
import '../services/api_service.dart';
import '../utils/ui_helpers.dart';
import 'job_board_screen.dart';

/// Consultazione Candidature di un annuncio (Scenario S3 - Requisito R7).
/// Carica `GET /jobs/<id>/applications` e apre i CV PDF via `GET /uploads/<fileName>`.
class JobApplicationsScreen extends StatefulWidget {
  final Job job;

  const JobApplicationsScreen({
    super.key,
    required this.job,
  });

  @override
  State<JobApplicationsScreen> createState() => _JobApplicationsScreenState();
}

class _JobApplicationsScreenState extends State<JobApplicationsScreen> {
  final ApiService _apiService = ApiService.instance;

  List<JobApplication> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      if (_applications.isEmpty) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final apps = await _apiService.fetchJobApplications(widget.job.id);
      if (!mounted) return;
      setState(() {
        _applications = apps;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        await _apiService.clearLocalSession();
        if (!mounted) return;
        showErrorSnackBar(context, 'Sessione scaduta. Effettua nuovamente il login.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const JobBoardScreen()),
          (route) => false,
        );
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

  void _openApplicationDetail(JobApplication application) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ApplicationDetailSheet(application: application),
    );
  }

  String _initials(JobApplication app) {
    final first = app.nome.isNotEmpty ? app.nome[0].toUpperCase() : '';
    final last = app.cognome.isNotEmpty ? app.cognome[0].toUpperCase() : '';
    final combined = '$first$last';
    return combined.isEmpty ? '?' : combined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidature Ricevute'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
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
                  '${_applications.length} candidature ricevute',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadApplications,
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
            Text('Caricamento candidature...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _applications.isEmpty) {
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
              onPressed: _loadApplications,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ),
        ],
      );
    }

    if (_applications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessuna candidatura ricevuta',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Quando un candidato invierà il proprio CV per questo annuncio, comparirà qui.',
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
      itemCount: _applications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final app = _applications[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                _initials(app),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              app.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(app.email),
                const SizedBox(height: 4),
                Text(
                  app.formattedDate,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openApplicationDetail(app),
          ),
        );
      },
    );
  }
}

class _ApplicationDetailSheet extends StatefulWidget {
  final JobApplication application;

  const _ApplicationDetailSheet({required this.application});

  @override
  State<_ApplicationDetailSheet> createState() => _ApplicationDetailSheetState();
}

class _ApplicationDetailSheetState extends State<_ApplicationDetailSheet> {
  bool _isOpeningPdf = false;

  Future<void> _openPdf() async {
    setState(() {
      _isOpeningPdf = true;
    });

    try {
      await ApiService.instance.openCvPdf(widget.application.cvFileName);
      if (!mounted) return;
      setState(() {
        _isOpeningPdf = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isOpeningPdf = false;
      });
      showErrorSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOpeningPdf = false;
      });
      showErrorSnackBar(context, 'Impossibile aprire il CV: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final app = widget.application;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.fullName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Candidatura ricevuta il ${app.formattedDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Nome',
                  value: app.nome,
                ),
                const Divider(height: 18),
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Cognome',
                  value: app.cognome,
                ),
                const Divider(height: 18),
                _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: app.email,
                ),
                const Divider(height: 18),
                _DetailRow(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Allegato CV',
                  value: app.cvFileName,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isOpeningPdf ? null : _openPdf,
              icon: _isOpeningPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _isOpeningPdf ? 'Apertura CV...' : 'Apri Curriculum (PDF)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
