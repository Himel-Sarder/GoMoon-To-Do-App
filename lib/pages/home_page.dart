import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TaskItem {
  String title;
  String description;
  DateTime dateTime;
  bool isDone;

  TaskItem({
    required this.title,
    required this.description,
    required this.dateTime,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() => {
    "title": title,
    "description": description,
    "dateTime": dateTime.toIso8601String(),
    "isDone": isDone,
  };

  static TaskItem fromMap(Map data) => TaskItem(
    title: (data["title"] ?? "").toString(),
    description: (data["description"] ?? "-").toString(),
    dateTime: DateTime.parse(data["dateTime"]),
    isDone: (data["isDone"] ?? false) as bool,
  );
}

enum TaskFilter { all, pending, done }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<TaskItem> tasks = [];

  // Search + filter
  String searchQuery = "";
  TaskFilter currentFilter = TaskFilter.all;

  // Add/Edit dialog controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  late final Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('tasksBox');
    _loadTasksFromHive();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ---------------------- Hive Save/Load ----------------------
  void _loadTasksFromHive() {
    final List raw = (_box.get('tasks', defaultValue: []) as List);

    final loaded = raw
        .map((e) => TaskItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    setState(() {
      tasks.clear();
      tasks.addAll(loaded);
    });
  }

  Future<void> _saveTasksToHive() async {
    final raw = tasks.map((t) => t.toMap()).toList();
    await _box.put('tasks', raw);
  }

  // ---------------------- helpers ----------------------
  DateTime? _combineDateTime() {
    if (_pickedDate == null || _pickedTime == null) return null;
    return DateTime(
      _pickedDate!.year,
      _pickedDate!.month,
      _pickedDate!.day,
      _pickedTime!.hour,
      _pickedTime!.minute,
    );
  }

  String niceDateTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "${dt.day}-${dt.month}-${dt.year}  $hh:$mm";
  }

  bool isOverdue(TaskItem task) {
    return !task.isDone && task.dateTime.isBefore(DateTime.now());
  }

  // ---------------------- Add/Edit dialog ----------------------
  void _openTaskDialog({
    required String dialogTitle,
    required VoidCallback onSave,
  }) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          void localSet(VoidCallback fn) {
            setLocal(fn);
            setState(() {});
          }

          final combined = _combineDateTime();

          return AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Task Title",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: context,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 5),
                              initialDate: _pickedDate ?? now,
                            );
                            if (d == null) return;
                            localSet(() => _pickedDate = d);
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            _pickedDate == null
                                ? "Pick Date"
                                : "${_pickedDate!.day}-${_pickedDate!.month}-${_pickedDate!.year}",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _pickedTime ?? TimeOfDay.now(),
                            );
                            if (t == null) return;
                            localSet(() => _pickedTime = t);
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _pickedTime == null
                                ? "Pick Time"
                                : _pickedTime!.format(context),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      combined == null
                          ? "Please select Date and Time"
                          : "Selected: ${niceDateTime(combined)}",
                      style: TextStyle(
                        color: combined == null ? Colors.red : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(onPressed: onSave, child: const Text("Save")),
            ],
          );
        },
      ),
    );
  }

  // ---------------------- Add Task ----------------------
  void openAddTaskDialog() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _pickedDate = null;
    _pickedTime = null;

    _openTaskDialog(
      dialogTitle: "Add New Task",
      onSave: () async {
        final title = _titleCtrl.text.trim();
        final desc = _descCtrl.text.trim();
        final dt = _combineDateTime();

        if (title.isEmpty || dt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enter title and select date & time."),
            ),
          );
          return;
        }

        setState(() {
          tasks.add(
            TaskItem(
              title: title,
              description: desc.isEmpty ? "-" : desc,
              dateTime: dt,
            ),
          );
        });

        await _saveTasksToHive();
        Navigator.pop(context);
      },
    );
  }

  // ---------------------- Edit Task ----------------------
  void openEditTaskDialog(TaskItem task) {
    _titleCtrl.text = task.title;
    _descCtrl.text = task.description == "-" ? "" : task.description;

    _pickedDate = DateTime(
      task.dateTime.year,
      task.dateTime.month,
      task.dateTime.day,
    );
    _pickedTime = TimeOfDay(
      hour: task.dateTime.hour,
      minute: task.dateTime.minute,
    );

    _openTaskDialog(
      dialogTitle: "Edit Task",
      onSave: () async {
        final title = _titleCtrl.text.trim();
        final desc = _descCtrl.text.trim();
        final dt = _combineDateTime();

        if (title.isEmpty || dt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enter title and select date & time."),
            ),
          );
          return;
        }

        setState(() {
          task.title = title;
          task.description = desc.isEmpty ? "-" : desc;
          task.dateTime = dt;
        });

        await _saveTasksToHive();
        Navigator.pop(context);
      },
    );
  }

  // ---------------------- Delete ----------------------
  void confirmDelete(int originalIndex) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Task"),
        content: const Text("Are you sure you want to delete this task?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              setState(() => tasks.removeAt(originalIndex));
              await _saveTasksToHive();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------------- Details ----------------------
  void openDetails(TaskItem task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailsPage(task: task)),
    );
  }

  // ---------------------- visible list (filter + search) ----------------------
  List<TaskItem> get visibleTasks {
    List<TaskItem> filtered = tasks;

    if (currentFilter == TaskFilter.pending) {
      filtered = filtered.where((t) => !t.isDone).toList();
    } else if (currentFilter == TaskFilter.done) {
      filtered = filtered.where((t) => t.isDone).toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q);
      }).toList();
    }

    filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return filtered;
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    final list = visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("GoMoon"),
        centerTitle: true,
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
      ),
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: openAddTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/bg.jpg", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.60)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      hintText: "Search by title or description...",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color.fromARGB(31, 48, 45, 45),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    cursorColor: Colors.white,
                    onChanged: (val) => setState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("All"),
                          selected: currentFilter == TaskFilter.all,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          selectedColor: Colors.white.withValues(alpha: 0.25),
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => currentFilter = TaskFilter.all),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Pending"),
                          selected: currentFilter == TaskFilter.pending,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          selectedColor: Colors.blue.withValues(alpha: 0.35),
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(
                            () => currentFilter = TaskFilter.pending,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Done"),
                          selected: currentFilter == TaskFilter.done,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          selectedColor: Colors.green.withValues(alpha: 0.35),
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => currentFilter = TaskFilter.done),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Text(
                              "No tasks found. Tap + to add one.",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final t = list[index];
                              final originalIndex = tasks.indexOf(t);
                              final overdue = isOverdue(t);

                              return Card(
                                color: overdue
                                    ? Colors.red.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                                elevation: overdue ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: overdue
                                      ? BorderSide(
                                          color: Colors.redAccent.withValues(
                                            alpha: 0.8,
                                          ),
                                          width: 1.2,
                                        )
                                      : BorderSide.none,
                                ),
                                child: ListTile(
                                  onTap: () => openDetails(t),
                                  title: Text(
                                    t.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      decoration: t.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    niceDateTime(t.dateTime),
                                    style: TextStyle(
                                      color: overdue
                                          ? Colors.redAccent
                                          : Colors.white70,
                                      fontWeight: overdue
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: t.isDone,
                                        activeColor: Colors.greenAccent,
                                        checkColor: Colors.black,
                                        onChanged: (_) async {
                                          setState(() => t.isDone = !t.isDone);
                                          await _saveTasksToHive();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.lightBlueAccent,
                                        ),
                                        onPressed: () => openEditTaskDialog(t),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            confirmDelete(originalIndex),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskDetailsPage extends StatelessWidget {
  final TaskItem task;
  const TaskDetailsPage({super.key, required this.task});

  String niceDateTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "${dt.day}-${dt.month}-${dt.year}  $hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Details"),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.white.withValues(alpha: 0.08),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      niceDateTime(task.dateTime),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Description",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.description,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      "Status: ",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      task.isDone ? "Done" : "Pending..",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
