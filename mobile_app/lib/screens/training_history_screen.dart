import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../models/training_session.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({super.key});

  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  String? _selectedCategory;
  String? _selectedGroup;

  List<TrainingSession> _filteredSessions(
    List<TrainingSession> sessions,
    Map<String, Person> personMap,
  ) {
    return sessions.where((s) {
      final person = personMap[s.personId];
      if (_selectedCategory != null && person?.category != _selectedCategory) return false;
      if (_selectedGroup != null && person?.group != _selectedGroup) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final settings = context.watch<SettingsService>();

    final sessions = db.getAllSessions();
    final personMap = {for (final p in db.getAllPersons()) p.id: p};
    final categories = settings.getCategories();
    final groups = settings.getGroups();
    final filtered = _filteredSessions(sessions, personMap);

    return Scaffold(
      body: Column(
        children: [
          // Filter bar
          if (categories.isNotEmpty || groups.isNotEmpty)
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (categories.isNotEmpty) ...[
                    _FilterRow(
                      label: 'Category',
                      options: categories,
                      selected: _selectedCategory,
                      onSelected: (v) => setState(() =>
                          _selectedCategory = _selectedCategory == v ? null : v),
                    ),
                  ],
                  if (groups.isNotEmpty) ...[
                    if (categories.isNotEmpty) const SizedBox(height: 4),
                    _FilterRow(
                      label: 'Group',
                      options: groups,
                      selected: _selectedGroup,
                      onSelected: (v) => setState(() =>
                          _selectedGroup = _selectedGroup == v ? null : v),
                    ),
                  ],
                ],
              ),
            ),
          // Session list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      sessions.isEmpty
                          ? 'No training sessions yet'
                          : 'No sessions match the current filter',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final session = filtered[i];
                      final person = personMap[session.personId];
                      return _SessionCard(session: session, person: person);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final active = selected == opt;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(opt, style: const TextStyle(fontSize: 12)),
                    selected: active,
                    onSelected: (_) => onSelected(opt),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TrainingSession session;
  final Person? person;

  const _SessionCard({required this.session, required this.person});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title.isNotEmpty ? session.title : session.trainingType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (!session.synced)
                  Icon(Icons.cloud_off, size: 13, color: Colors.grey[400]),
              ],
            ),
            if (person != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.person, size: 12, color: colorScheme.primary),
                const SizedBox(width: 3),
                Text(person!.name, style: const TextStyle(fontSize: 12)),
                if (person!.category != null) ...[
                  const SizedBox(width: 6),
                  Text(person!.category!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
                if (person!.group != null) ...[
                  const SizedBox(width: 3),
                  Text('· ${person!.group!}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ]),
            ],
            const SizedBox(height: 8),
            // Two-column body
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: general info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Stat(icon: Icons.calendar_today, label: _formatDate(session.startTime)),
                      const SizedBox(height: 3),
                      _Stat(icon: Icons.timer, label: _formatDuration(session.duration)),
                      const SizedBox(height: 3),
                      _Stat(icon: Icons.sports, label: session.trainingType),
                    ],
                  ),
                ),
                // Divider
                Container(width: 1, height: 48, color: Colors.grey.withValues(alpha: 0.25),
                    margin: const EdgeInsets.symmetric(horizontal: 10)),
                // Right: HR stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session.avgHeartRate != null)
                        _Stat(icon: Icons.favorite,
                            label: 'Avg  ${session.avgHeartRate} bpm',
                            color: Colors.orange),
                      if (session.maxHeartRate != null) ...[
                        const SizedBox(height: 3),
                        _Stat(icon: Icons.trending_up,
                            label: 'Max  ${session.maxHeartRate} bpm',
                            color: Colors.red),
                      ],
                      if (session.minHeartRate != null) ...[
                        const SizedBox(height: 3),
                        _Stat(icon: Icons.trending_down,
                            label: 'Min  ${session.minHeartRate} bpm',
                            color: Colors.blue),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Stat({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? Colors.grey[600]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700])),
      ],
    );
  }
}
