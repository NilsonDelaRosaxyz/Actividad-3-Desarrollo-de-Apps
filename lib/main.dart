import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────
void main() {
  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// Theme & App root
// ─────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _udcYellow = Color(0xFFF5C400);
  static const Color _udcBlue = Color(0xFF003B70);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda UDC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _udcBlue,
          brightness: Brightness.light,
        ).copyWith(secondary: _udcYellow),
        scaffoldBackgroundColor: const Color(0xFFFFFAE8),
        appBarTheme: const AppBarTheme(
          backgroundColor: _udcYellow,
          foregroundColor: _udcBlue,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _udcYellow,
          foregroundColor: _udcBlue,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      // Start at LoginPage; it redirects to TaskHomePage on success
      home: const LoginPage(),
    );
  }
}

// ─────────────────────────────────────────────
// SharedPreferences keys
// ─────────────────────────────────────────────
const String _kUsers = 'udc_users';       // JSON map {username: password}
const String _kLoggedIn = 'udc_logged_in'; // String: current username or ''
const String _kTasks = 'udc_tasks';        // JSON list of tasks

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────
class TaskItem {
  TaskItem({
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.priority,
    this.isDone = false,
  });

  final String title;
  final String subject;
  final DateTime dueDate;
  final String priority;
  bool isDone;

  Map<String, dynamic> toJson() => {
        'title': title,
        'subject': subject,
        'dueDate': dueDate.toIso8601String(),
        'priority': priority,
        'isDone': isDone,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        title: j['title'] as String,
        subject: j['subject'] as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        priority: j['priority'] as String,
        isDone: j['isDone'] as bool? ?? false,
      );
}

enum TaskFilter { all, pending, done }

// ─────────────────────────────────────────────
// LOGIN PAGE
// ─────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Check if there is already a session saved
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLoggedIn) ?? '';
    if (saved.isNotEmpty && mounted) {
      _goHome(saved);
    }
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_kUsers);
    final users = usersJson != null
        ? Map<String, String>.from(
            (jsonDecode(usersJson) as Map).map(
              (k, v) => MapEntry(k as String, v as String),
            ),
          )
        : <String, String>{};

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (users.containsKey(username) && users[username] == password) {
      await prefs.setString(_kLoggedIn, username);
      if (mounted) _goHome(username);
    } else {
      setState(() {
        _loading = false;
        _error = 'Usuario o contraseña incorrectos.';
      });
    }
  }

  void _goHome(String username) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TaskHomePage(username: username)),
    );
  }

  void _goRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / title
                  const Icon(Icons.school, size: 72, color: Color(0xFF003B70)),
                  const SizedBox(height: 8),
                  Text(
                    'Agenda UDC',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: const Color(0xFF003B70)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Universidad de Cartagena',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),

                  // Username
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                  ),

                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ],

                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Register link
                  TextButton(
                    onPressed: _goRegister,
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REGISTER PAGE
// ─────────────────────────────────────────────
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_kUsers);
    final users = usersJson != null
        ? Map<String, String>.from(
            (jsonDecode(usersJson) as Map).map(
              (k, v) => MapEntry(k as String, v as String),
            ),
          )
        : <String, String>{};

    final username = _usernameCtrl.text.trim();

    if (users.containsKey(username)) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese nombre de usuario ya existe.')),
      );
      return;
    }

    users[username] = _passwordCtrl.text;
    await prefs.setString(_kUsers, jsonEncode(users));

    setState(() => _loading = false);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Cuenta creada!'),
        content: Text('Bienvenido, $username. Ya puedes iniciar sesión.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.of(context).pop(); // back to login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Registro',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // Username
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa un nombre de usuario';
                      }
                      if (v.trim().length < 3) {
                        return 'Mínimo 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                      if (v.length < 4) return 'Mínimo 4 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Registrarse'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME PAGE (Task Manager)
// ─────────────────────────────────────────────
class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key, required this.username});
  final String username;

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final List<TaskItem> _tasks = [];
  TaskFilter _currentFilter = TaskFilter.all;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // ── Persistence ──────────────────────────────
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_kTasks);
    if (encoded != null) {
      final List<dynamic> decoded = jsonDecode(encoded) as List<dynamic>;
      _tasks
        ..clear()
        ..addAll(decoded
            .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .toList());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kTasks, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  // ── Computed ─────────────────────────────────
  List<TaskItem> get _filteredTasks {
    switch (_currentFilter) {
      case TaskFilter.pending:
        return _tasks.where((t) => !t.isDone).toList();
      case TaskFilter.done:
        return _tasks.where((t) => t.isDone).toList();
      case TaskFilter.all:
        return _tasks;
    }
  }

  int get _doneCount => _tasks.where((t) => t.isDone).length;

  // ── Task form (add) ───────────────────────────
  Future<void> _showTaskForm() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedPriority = 'Media';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nuevo pendiente',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),

                  // Activity title
                  TextFormField(
                    controller: titleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Actividad'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa una actividad'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Subject
                  TextFormField(
                    controller: subjectCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Materia'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa la materia'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Date picker
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModal(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                          'Entrega: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Priority dropdown
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration:
                        const InputDecoration(labelText: 'Prioridad'),
                    items: const [
                      DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      DropdownMenuItem(
                          value: 'Media', child: Text('Media')),
                      DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModal(() => selectedPriority = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setState(() {
                            _tasks.add(TaskItem(
                              title: titleCtrl.text.trim(),
                              subject: subjectCtrl.text.trim(),
                              dueDate: selectedDate,
                              priority: selectedPriority,
                            ));
                          });
                          await _saveTasks();
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Pendiente agregado correctamente')),
                          );
                        }
                      },
                      child: const Text('Guardar pendiente'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── Delete with confirmation ──────────────────
  Future<void> _confirmDeleteTask(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pendiente'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _tasks.removeAt(index));
      await _saveTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendiente eliminado')),
      );
    }
  }

  // ── Clear all with confirmation ───────────────
  Future<void> _clearAllTasks() async {
    if (_tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pendientes para limpiar')),
      );
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar lista'),
        content: const Text('Se eliminarán todos los pendientes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      setState(_tasks.clear);
      await _saveTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lista limpiada')));
    }
  }

  // ── Toggle done ───────────────────────────────
  Future<void> _toggleTask(int index, bool value) async {
    setState(() => _tasks[index].isDone = value);
    await _saveTasks();
  }

  // ── Logout ────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLoggedIn);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Pendientes UDC',
            overflow: TextOverflow.ellipsis),
        actions: [
          // Filter menu
          PopupMenuButton<TaskFilter>(
            tooltip: 'Filtrar',
            initialValue: _currentFilter,
            onSelected: (f) => setState(() => _currentFilter = f),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: TaskFilter.all, child: Text('Ver todos')),
              PopupMenuItem(
                  value: TaskFilter.pending,
                  child: Text('Solo pendientes')),
              PopupMenuItem(
                  value: TaskFilter.done, child: Text('Completados')),
            ],
          ),
        ],
      ),

      // ── Drawer ──────────────────────────────────
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              color: colorScheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_circle,
                      size: 56, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    widget.username,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text('Total: ${_tasks.length} pendientes',
                      style: const TextStyle(color: Colors.white70)),
                  Text('Completados: $_doneCount',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            // Actions
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Limpiar toda la lista'),
              onTap: () {
                Navigator.pop(context);
                _clearAllTasks();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            const Divider(),

            // App info
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('ACTIVIDAD #3 - Desarrollo de Apps'),
              subtitle: Text('Facultad de Ingeniería - U. de Cartagena'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Text('Cipa T.N:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              child: Text('Nicolas Julian Torres Torres'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              child: Text('Nilson Emmanuelle De la Rosa Cardales'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              child: Text('Thalma Pardo Julio'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 1),
              child: Text('Tutor: HEYBERTT MORENO DIAZ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 1, 16, 12),
              child: Text('Ingeniería de Software - 7mo Semestre'),
            ),
          ],
        ),
      ),

      // ── Body ────────────────────────────────────
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTasks.isEmpty
              ? const Center(
                  child: Text('No hay actividades para mostrar.'))
              : ListView.builder(
                  itemCount: _filteredTasks.length,
                  itemBuilder: (_, visibleIndex) {
                    final task = _filteredTasks[visibleIndex];
                    final originalIndex = _tasks.indexOf(task);

                    // Priority color indicator
                    final priorityColor = task.priority == 'Alta'
                        ? Colors.red
                        : task.priority == 'Media'
                            ? Colors.orange
                            : Colors.green;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: Colors.white,
                      child: ListTile(
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (v) =>
                              _toggleTask(originalIndex, v ?? false),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${task.subject} · ${task.priority} · '
                                '${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _confirmDeleteTask(originalIndex),
                        ),
                      ),
                    );
                  },
                ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTaskForm,
        icon: const Icon(Icons.add_task),
        label: const Text('Agregar'),
      ),
    );
  }
}
