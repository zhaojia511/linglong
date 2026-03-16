import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _maxHRController = TextEditingController();
  final _restingHRController = TextEditingController();
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final person =
        Provider.of<DatabaseService>(context, listen: false).currentPerson;
    if (person != null) {
      _nameController.text = person.name;
      _ageController.text = person.age.toString();
      _weightController.text = person.weight.toString();
      _heightController.text = person.height.toString();
      _maxHRController.text = person.maxHeartRate?.toString() ?? '';
      _restingHRController.text = person.restingHeartRate?.toString() ?? '';
      _gender = person.gender;
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
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);

      final person = dbService.currentPerson;

      if (person == null) {
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
        );

        if (syncService.isAuthenticated) {
          await syncService.syncPerson(newPerson);
        }
      } else {
        // Update existing person
        person.name = _nameController.text;
        person.age = int.parse(_ageController.text);
        person.gender = _gender;
        person.weight = double.parse(_weightController.text);
        person.height = double.parse(_heightController.text);
        person.maxHeartRate = _maxHRController.text.isNotEmpty
            ? int.parse(_maxHRController.text)
            : null;
        person.restingHeartRate = _restingHRController.text.isNotEmpty
            ? int.parse(_restingHRController.text)
            : null;

        await dbService.updatePerson(person);

        if (syncService.isAuthenticated) {
          await syncService.syncPerson(person);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _showSyncDialog(context),
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
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
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
                        DropdownMenuItem(
                            value: 'female', child: Text('Female')),
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
                'Optional Heart Rate Information',
                style: TextStyle(
                  fontSize: 16,
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
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SyncDialog(),
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
