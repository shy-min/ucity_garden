import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/moderation.dart';
import '../services/user_service.dart';
import '../theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  final _eventsStream = FirebaseFirestore.instance.collection('events').orderBy('date').snapshots();
  final _blockedStream = UserService.instance.blockedIds();

  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final base = _selectedDay ?? DateTime.now();
    DateTime pickedDate = DateTime(base.year, base.month, base.day);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create New Event', style: TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 15),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Event Title', fillColor: AppColors.background),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description', fillColor: AppColors.background),
                maxLines: 3,
              ),
              const SizedBox(height: 15),
              ListTile(
                tileColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                leading: const Icon(Icons.calendar_today, color: AppColors.green),
                title: Text('Date: ${formatDate(pickedDate)}', style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: pickedDate.isBefore(now) ? now : pickedDate,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(now.year + 3, 12, 31),
                  );
                  if (date != null) setModalState(() => pickedDate = DateTime(date.year, date.month, date.day));
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) {
                          showSnack(context, 'Please give the event a title.');
                          return;
                        }
                        setModalState(() => saving = true);
                        final user = fb.FirebaseAuth.instance.currentUser!;
                        await FirebaseFirestore.instance.collection('events').add({
                          'title': titleController.text.trim(),
                          'description': descController.text.trim(),
                          'date': Timestamp.fromDate(pickedDate),
                          'creatorId': user.uid,
                          'creatorName': await UserService.instance.currentDisplayName(),
                          'rsvps': [user.uid],
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Publish Event'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  void _showTasksDialog(BuildContext context, String eventId, String eventTitle, String? eventCreatorId) {
    final taskController = TextEditingController();
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;
    final tasksRef = FirebaseFirestore.instance.collection('events').doc(eventId).collection('tasks');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              children: [
                Text('Volunteer Tasks: $eventTitle',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: tasksRef.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text("Couldn't load tasks."));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final tasks = snapshot.data!.docs;
                      if (tasks.isEmpty) {
                        return const Center(
                            child: Text('No volunteer tasks yet. Add one below.', style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final data = task.data();
                          final assigneeId = data['assigneeId'] as String?;
                          final isClaimed = assigneeId != null;
                          final isMine = assigneeId == currentUserId;
                          final canDelete = data['creatorId'] == currentUserId || eventCreatorId == currentUserId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onLongPress: canDelete
                                ? () async {
                                    if (await Moderation.confirm(context, 'Delete task?', data['name'] ?? '', 'Delete')) {
                                      await task.reference.delete();
                                    }
                                  }
                                : null,
                            title: Text(data['name'] ?? '',
                                style: TextStyle(
                                    color: isClaimed && !isMine ? Colors.grey : Colors.white,
                                    decoration: isClaimed && !isMine ? TextDecoration.lineThrough : null)),
                            subtitle: isClaimed
                                ? Text(isMine ? 'You' : (data['assigneeName'] ?? 'Taken'),
                                    style: const TextStyle(color: Colors.grey))
                                : null,
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isMine ? Colors.red : (isClaimed ? Colors.grey : AppColors.green)),
                              onPressed: isClaimed && !isMine
                                  ? null
                                  : () async {
                                      if (isMine) {
                                        await task.reference.update({'assigneeId': null, 'assigneeName': null});
                                      } else {
                                        await task.reference.update({
                                          'assigneeId': currentUserId,
                                          'assigneeName': await UserService.instance.currentDisplayName(),
                                        });
                                      }
                                    },
                              child: Text(isMine ? 'Unclaim' : (isClaimed ? 'Taken' : 'Claim')),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taskController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Add Task...', fillColor: AppColors.background),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.green, size: 32),
                        onPressed: () async {
                          final name = taskController.text.trim();
                          if (name.isEmpty) return;
                          taskController.clear();
                          await tasksRef.add({
                            'name': name,
                            'assigneeId': null,
                            'assigneeName': null,
                            'creatorId': currentUserId,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleRsvp(String eventId, List currentRsvps) async {
    final userId = fb.FirebaseAuth.instance.currentUser!.uid;
    final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
    await eventRef.update({
      'rsvps': currentRsvps.contains(userId) ? FieldValue.arrayRemove([userId]) : FieldValue.arrayUnion([userId]),
    });
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('The Garden Events')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New event',
        onPressed: () => _showAddEventDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<Set<String>>(
        stream: _blockedStream,
        builder: (context, blockedSnap) {
          final blocked = blockedSnap.data ?? const <String>{};
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _eventsStream,
            builder: (context, snapshot) {
              final docs = (snapshot.data?.docs ?? [])
                  .where((d) => d.data()['date'] is Timestamp && !blocked.contains(d.data()['creatorId']))
                  .toList();
              List<QueryDocumentSnapshot<Map<String, dynamic>>> eventsOn(DateTime day) =>
                  docs.where((d) => _sameDay((d.data()['date'] as Timestamp).toDate(), day)).toList();

              final selectedEvents = _selectedDay == null ? <QueryDocumentSnapshot<Map<String, dynamic>>>[] : eventsOn(_selectedDay!);

              return Column(
                children: [
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: eventsOn,
                    onDaySelected: (selectedDay, focusedDay) =>
                        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
                    onPageChanged: (focused) => _focusedDay = focused,
                    rowHeight: 44,
                    calendarStyle: const CalendarStyle(
                      defaultTextStyle: TextStyle(color: Colors.white),
                      weekendTextStyle: TextStyle(color: Colors.white70),
                      outsideTextStyle: TextStyle(color: Colors.white24),
                      todayDecoration: BoxDecoration(color: Color(0x551ca931), shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                      markerDecoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      markersMaxCount: 3,
                    ),
                    headerStyle: const HeaderStyle(
                      titleTextStyle: TextStyle(color: Colors.white, fontSize: 17),
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  Expanded(
                    child: Builder(builder: (context) {
                      if (snapshot.hasError) {
                        return const Center(child: Text("Couldn't load events. Check your connection."));
                      }
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (selectedEvents.isEmpty) {
                        return const Center(
                            child: Text('No events on this day.', style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: selectedEvents.length,
                        itemBuilder: (context, index) {
                          final doc = selectedEvents[index];
                          final eventData = doc.data();
                          final List rsvps = eventData['rsvps'] ?? [];
                          final isGoing = rsvps.contains(currentUserId);
                          final title = (eventData['title'] ?? 'Untitled') as String;
                          final desc = (eventData['description'] ?? '') as String;
                          final creatorId = eventData['creatorId'] as String?;
                          return Card(
                            color: AppColors.surface,
                            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_horiz),
                                      tooltip: 'More',
                                      onPressed: () => Moderation.showActions(context,
                                          contentType: 'event',
                                          ref: doc.reference,
                                          ownerId: creatorId,
                                          ownerName: eventData['creatorName'],
                                          excerpt: title),
                                    ),
                                  ]),
                                  if (desc.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Text(desc, style: const TextStyle(color: Colors.white70)),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.people_outline, size: 18, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('${rsvps.length} going', style: const TextStyle(color: Colors.grey)),
                                    const Spacer(),
                                    TextButton.icon(
                                      icon: const Icon(Icons.checklist, color: AppColors.green),
                                      label: const Text('Volunteer', style: TextStyle(color: AppColors.green)),
                                      onPressed: () => _showTasksDialog(context, doc.id, title, creatorId),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: isGoing ? Colors.grey.shade700 : AppColors.green),
                                      onPressed: () => _toggleRsvp(doc.id, rsvps),
                                      child: Text(isGoing ? 'Going ✓' : 'RSVP'),
                                    ),
                                    const SizedBox(width: 8),
                                  ]),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
