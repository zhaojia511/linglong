import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../services/database_service.dart';
import '../services/supabase_repository.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _showSyncDialog(context),
          ),
        ],
      ),
      body: Consumer<DatabaseService>(
        builder: (context, dbService, child) {
          final persons = dbService.getAllPersons();

          if (persons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No team members yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PersonDetailScreen(person: null),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Team Member'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: persons.length,
            itemBuilder: (context, index) {
              final person = persons[index];
              final isCurrent = dbService.currentPerson?.id == person.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColorForPerson(index),
                    child: Text(
                      person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(person.name),
                  subtitle: Text(_buildSubtitle(person)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(person: person),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'profile_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PersonDetailScreen(person: null),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Member'),
      ),
    );
  }

  Color _getColorForPerson(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SyncDialog(),
    );
  }

  String _buildSubtitle(person) {
    final parts = <String>[];
    parts.add('${person.age} years');
    final gender = person.gender;
    parts.add(gender.isNotEmpty ? '${gender[0].toUpperCase()}${gender.substring(1)}' : gender);
    if (person.category != null && person.category!.isNotEmpty) parts.add(person.category!);
    if (person.group != null && person.group!.isNotEmpty) parts.add(person.group!);
    return parts.join(' • ');
  }
}

class PersonDetailScreen extends StatefulWidget {
  final Person? person;

  const PersonDetailScreen({super.key, this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _maxHRController;
  late final TextEditingController _restingHRController;
  late final TextEditingController _categoryController;
  late final TextEditingController _groupController;
  late String _gender;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _maxHRController = TextEditingController();
    _restingHRController = TextEditingController();
    _categoryController = TextEditingController();
    _groupController = TextEditingController();
    _gender = 'male';

    if (widget.person != null) {
      _nameController.text = widget.person!.name;
      _ageController.text = widget.person!.age.toString();
      _weightController.text = widget.person!.weight.toString();
      _heightController.text = widget.person!.height.toString();
      _maxHRController.text = widget.person!.maxHeartRate?.toString() ?? '';
      _restingHRController.text = widget.person!.restingHeartRate?.toString() ?? '';
      _categoryController.text = widget.person!.category ?? '';
      _groupController.text = widget.person!.group ?? '';
      _gender = widget.person!.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _maxHRController.dispose();
    _restingHRController.dispose();
    _categoryController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  void _savePerson() async {
    if (_formKey.currentState!.validate()) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final supabaseRepo = SupabaseRepository();

      try {
        if (widget.person == null) {
          // Create new person
          final newPerson = await dbService.createPerson(
            name: _nameController.text,
            age: int.parse(_ageController.text),
            gender: _gender,
            weight: double.parse(_weightController.text),
            height: double.parse(_heightController.text),
            maxHeartRate: _maxHRController.text.isNotEmpty
                ? int.parse(_maxHRController.text)
                : null,
            restingHeartRate: _restingHRController.text.isNotEmpty
                ? int.parse(_restingHRController.text)
                : null,
            category: _categoryController.text.isEmpty ? null : _categoryController.text,
            group: _groupController.text.isEmpty ? null : _groupController.text,
          );

          // Always upsert to Supabase
          await supabaseRepo.upsertPerson(
            name: newPerson.name,
            age: newPerson.age,
            gender: newPerson.gender,
            weight: newPerson.weight,
            height: newPerson.height,
            maxHeartRate: newPerson.maxHeartRate,
            restingHeartRate: newPerson.restingHeartRate,
            id: newPerson.id,
          );
        } else {
          // Update existing person
          widget.person!.name = _nameController.text;
          widget.person!.age = int.parse(_ageController.text);
          widget.person!.gender = _gender;
          widget.person!.weight = double.parse(_weightController.text);
          widget.person!.height = double.parse(_heightController.text);
          widget.person!.maxHeartRate = _maxHRController.text.isNotEmpty
              ? int.parse(_maxHRController.text)
              : null;
          widget.person!.restingHeartRate = _restingHRController.text.isNotEmpty
              ? int.parse(_restingHRController.text)
              : null;
          widget.person!.category = _categoryController.text.isEmpty ? null : _categoryController.text;
          widget.person!.group = _groupController.text.isEmpty ? null : _groupController.text;

          await dbService.updatePerson(widget.person!);

          // Always upsert to Supabase
          await supabaseRepo.upsertPerson(
            name: widget.person!.name,
            age: widget.person!.age,
            gender: widget.person!.gender,
            weight: widget.person!.weight,
            height: widget.person!.height,
            maxHeartRate: widget.person!.maxHeartRate,
            restingHeartRate: widget.person!.restingHeartRate,
            id: widget.person!.id,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team member saved')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _deletePerson() {
    if (widget.person == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team Member'),
        content: Text(
          'Are you sure you want to delete "${widget.person!.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final dbService =
                  Provider.of<DatabaseService>(context, listen: false);
              
              await dbService.deletePerson(widget.person!.id);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team member deleted')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person == null ? 'Add Team Member' : 'Edit ${widget.person!.name}'),
        actions: [
          if (widget.person != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deletePerson,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Consumer<SettingsService>(
                builder: (context, settings, child) {
                  final categories = settings.getCategories();
                  return DropdownButtonFormField<String>(
                    value: _categoryController.text.isEmpty ? null : _categoryController.text,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      hintText: 'Select category',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...categories.map((cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _categoryController.text = value ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Consumer<SettingsService>(
                builder: (context, settings, child) {
                  final groups = settings.getGroups();
                  return DropdownButtonFormField<String>(
                    value: _groupController.text.isEmpty ? null : _groupController.text,
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      border: OutlineInputBorder(),
                      hintText: 'Select group',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...groups.map((grp) => DropdownMenuItem<String>(
                        value: grp,
                        child: Text(grp),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _groupController.text = value ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        suffixText: 'years',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age < 1 || age > 120) {
                          return 'Invalid age';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _gender = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        border: OutlineInputBorder(),
                        suffixText: 'kg',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final weight = double.tryParse(value);
                        if (weight == null || weight < 20 || weight > 300) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        border: OutlineInputBorder(),
                        suffixText: 'cm',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final height = double.tryParse(value);
                        if (height == null || height < 50 || height > 250) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Heart Rate Information (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxHRController,
                      decoration: const InputDecoration(
                        labelText: 'Max HR',
                        border: OutlineInputBorder(),
                        suffixText: 'bpm',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _restingHRController,
                      decoration: const InputDecoration(
                        labelText: 'Resting HR',
                        border: OutlineInputBorder(),
                        suffixText: 'bpm',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _savePerson,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(widget.person == null ? 'Add Member' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SyncDialog extends StatelessWidget {
  const SyncDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Settings'),
      content: Consumer<SyncService>(
        builder: (context, syncService, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncService.isAuthenticated)
                Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Connected'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await syncService.syncAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sync completed')),
                          );
                        }
                      },
                      child: syncService.isSyncing
                          ? const CircularProgressIndicator()
                          : const Text('Sync Now'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await syncService.logout();
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                )
              else
                const Text('Please configure backend server to enable sync'),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
