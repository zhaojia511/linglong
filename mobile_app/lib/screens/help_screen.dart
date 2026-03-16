import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help'), toolbarHeight: 48),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _Section(
            icon: Icons.rocket_launch,
            title: 'Getting Started',
            color: Colors.blue,
            items: [
              _Item('What is Linglong HR Monitor?',
                  'A real-time heart rate monitoring app for team sports coaches. '
                  'Connect multiple BLE chest-strap sensors simultaneously and view '
                  'every athlete\'s heart rate on one screen during training.'),
              _Item('What do I need?',
                  '• One BLE (Bluetooth Low Energy) ANT+ or standard HR chest strap per athlete.\n'
                  '• iOS or Android device with Bluetooth enabled.\n'
                  '• Optional: a Supabase account to sync data across devices.'),
            ],
          ),
          _Section(
            icon: Icons.bluetooth,
            title: 'Connecting Sensors',
            color: Colors.indigo,
            items: [
              _Item('How do I connect a sensor?',
                  '1. Strap the HR chest strap on the athlete and make sure it is wet/active.\n'
                  '2. Open the Dashboard screen.\n'
                  '3. Tap the Bluetooth icon (top-left) to open the device scanner.\n'
                  '4. Wait for the sensor to appear in the list, then tap it.\n'
                  '5. A green tick appears when connected.'),
              _Item('Why can\'t I see my sensor?',
                  '• Make sure Bluetooth is enabled on your device.\n'
                  '• Grant Bluetooth permissions if prompted.\n'
                  '• Ensure the chest strap is moist — dry electrodes don\'t broadcast.\n'
                  '• Tap "Rescan" in the device dialog.'),
              _Item('How many sensors can I connect?',
                  'Up to 20 sensors simultaneously. The dashboard shows a 5 × 4 grid '
                  '(20 slots). Empty slots appear dimmed until a sensor is connected.'),
              _Item('Saved devices',
                  'Previously connected sensors appear in a "Saved Devices" list inside '
                  'the scanner. Tap one to reconnect without a full scan. '
                  'The app also auto-reconnects to saved devices on startup.'),
            ],
          ),
          _Section(
            icon: Icons.person_pin,
            title: 'Assigning Sensors to Athletes',
            color: Colors.teal,
            items: [
              _Item('How do I assign a sensor to an athlete?',
                  '1. First add athletes on the Profile screen (person icon in the nav bar).\n'
                  '2. On the Dashboard, tap any connected sensor card.\n'
                  '3. Choose the athlete from the list.\n'
                  'The card will display the athlete\'s name from that point on.'),
              _Item('Can one sensor be shared?',
                  'No — each sensor is exclusively assigned to one athlete. '
                  'Assigning it to a new athlete automatically removes the previous assignment.'),
              _Item('What if I don\'t assign?',
                  'The card shows "Tap to assign" and still displays live heart rate. '
                  'Sessions are recorded but linked to no specific athlete profile.'),
            ],
          ),
          _Section(
            icon: Icons.monitor_heart,
            title: 'Dashboard & Training Zones',
            color: Colors.red,
            items: [
              _Item('What do the card colours mean?',
                  'Each card background reflects the athlete\'s current training zone:\n'
                  '• Blue — Recovery (< 120 bpm)\n'
                  '• Green — Aerobic (120–149 bpm)\n'
                  '• Amber — Tempo (150–169 bpm)\n'
                  '• Deep Orange — Threshold (170–189 bpm)\n'
                  '• Red — Anaerobic (≥ 190 bpm)'),
              _Item('What is shown on each card?',
                  '• Athlete name (top)\n'
                  '• Live BPM (large centre number)\n'
                  '• Training zone label\n'
                  '• Battery level (if sensor supports it)'),
            ],
          ),
          _Section(
            icon: Icons.play_circle,
            title: 'Recording a Training Session',
            color: Colors.green,
            items: [
              _Item('How do I start a session?',
                  '1. Connect at least one sensor.\n'
                  '2. Tap the green "Start Training" button (bottom-right).\n'
                  'Heart rate is recorded every second for all connected sensors.'),
              _Item('How do I stop?',
                  'Tap the red "Stop Training" button. Stats (avg, max, min HR, calories) '
                  'are calculated automatically and the session is saved locally.'),
              _Item('Where are sessions saved?',
                  'Sessions are stored on-device first (works offline). '
                  'When you are signed in to the cloud, unsynced sessions are uploaded '
                  'automatically. A cloud icon on each history card shows sync status.'),
            ],
          ),
          _Section(
            icon: Icons.history,
            title: 'Training History & Filters',
            color: Colors.purple,
            items: [
              _Item('How do I view past sessions?',
                  'Tap "History" in the bottom navigation bar. '
                  'Sessions are listed newest first.'),
              _Item('How do the filters work?',
                  'If you have added Categories or Groups in Settings, filter chips '
                  'appear at the top of the History screen. '
                  'Tap a chip to show only sessions from athletes in that category or group. '
                  'Tap it again to clear the filter. Both filters can be active at once.'),
              _Item('How do I see session details?',
                  'Tap any session card to open the detail view with:\n'
                  '• Heart rate chart over time\n'
                  '• HRV analysis (Poincaré plot, rolling RMSSD, metrics)'),
            ],
          ),
          _Section(
            icon: Icons.cloud_sync,
            title: 'Cloud Sync',
            color: Colors.cyan,
            items: [
              _Item('How do I set up sync?',
                  '1. Go to Settings → Supabase Cloud Sync.\n'
                  '2. Tap "Sign In" and enter your email and password.\n'
                  'On first sign-in, your local data is pushed to the cloud immediately.'),
              _Item('What syncs automatically?',
                  '• Athlete profiles (name, age, HR zones, category, group)\n'
                  '• Completed training sessions\n'
                  '• Categories and groups\n\n'
                  'Sync happens on login and when you tap "Sync Now" on the Profile screen.'),
              _Item('Same account on two devices?',
                  'Sign in with the same account on both devices. '
                  'On login, cloud data is downloaded and merged with local data. '
                  'Local unsynced sessions are uploaded. '
                  'Athlete profiles are merged by ID — no duplicates.'),
            ],
          ),
          _Section(
            icon: Icons.monitor_heart_outlined,
            title: 'HRV Analysis',
            color: Colors.orange,
            items: [
              _Item('What is HRV?',
                  'Heart Rate Variability (HRV) measures the millisecond fluctuations '
                  'between consecutive heartbeats (RR intervals). '
                  'Higher variability generally indicates better recovery and parasympathetic tone.'),
              _Item('Key metrics explained',
                  '• RMSSD — Root mean square of successive differences. '
                  'The primary acute HRV metric. > 40 ms = good, < 20 ms = high stress/fatigue.\n\n'
                  '• SDNN — Standard deviation of all RR intervals. '
                  'Reflects overall autonomic activity.\n\n'
                  '• pNN50 — Percentage of beat pairs differing by > 50 ms. '
                  'Higher = stronger vagal (rest-and-digest) tone.\n\n'
                  '• SD1 / SD2 — Poincaré plot axes. '
                  'SD1 = short-term (beat-to-beat) variability driven by breathing. '
                  'SD2 = longer-term variability. SD1/SD2 ratio < 0.25 suggests sympathetic dominance.'),
              _Item('Poincaré plot',
                  'A scatter plot where each dot represents a pair of consecutive RR intervals '
                  '(RR[i] on X, RR[i+1] on Y). '
                  'A tight, narrow cluster means low HRV (high effort or stress). '
                  'A wide ellipse means strong variability (good recovery or rest).'),
              _Item('Rolling RMSSD chart',
                  'Shows how RMSSD changes through the session using a sliding window. '
                  'A declining trend means increasing fatigue load. '
                  'The red dashed line marks 20 ms — values below this indicate high stress.'),
              _Item('Important caveat',
                  'The app derives RR intervals from BPM values recorded each second '
                  '(60000 ÷ BPM). This is an approximation. '
                  'For true HRV accuracy, use a sensor that broadcasts raw RR intervals '
                  'over BLE (e.g., Polar H10). During exercise, HRV naturally suppresses — '
                  'compare trends within a session rather than absolute values.'),
            ],
          ),
          _Section(
            icon: Icons.group,
            title: 'Managing Athletes',
            color: Colors.brown,
            items: [
              _Item('How do I add an athlete?',
                  'Go to the Profile screen → tap the + button. '
                  'Fill in name, age, gender, weight, height and optional HR zone info. '
                  'Assign a category and group if needed.'),
              _Item('What are categories and groups?',
                  'Free-form labels you define in Settings. Examples:\n'
                  '• Category: "Senior", "Junior", "U18"\n'
                  '• Group: "Attack", "Defence", "Midfield"\n\n'
                  'They appear as filters in Training History and on session cards.'),
              _Item('How do I delete an athlete?',
                  'Open the athlete\'s detail on the Profile screen and scroll to the bottom. '
                  'Tap "Delete" and confirm. Their past sessions remain in history.'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section ────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<_Item> items;

  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        childrenPadding: EdgeInsets.zero,
        children: items
            .map((item) => _ItemTile(item: item))
            .toList(),
      ),
    );
  }
}

// ── Item ───────────────────────────────────────────────────────────────────

class _Item {
  final String question;
  final String answer;
  const _Item(this.question, this.answer);
}

class _ItemTile extends StatelessWidget {
  final _Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: Text(item.question,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(item.answer,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
        ),
      ],
    );
  }
}
