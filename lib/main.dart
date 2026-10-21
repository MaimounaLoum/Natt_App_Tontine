import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';

// ==========================================
// VARIABLES GLOBALES (PERSISTANTES A BLANC)
// ==========================================
List<Map<String, dynamic>> globalTontinesList = [];
List<Map<String, dynamic>> globalMembersList = [];
Map<String, dynamic>? currentConnectedMember;

// --- ALGORITHMES DE SAUVEGARDE LOCALE ---
Future<void> saveTontinesToLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String rawJson = jsonEncode(globalTontinesList);
  await prefs.setString('natt_tontines', rawJson);
}

Future<void> loadTontinesFromLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String? rawJson = prefs.getString('natt_tontines');
  if (rawJson != null) {
    globalTontinesList = List<Map<String, dynamic>>.from(jsonDecode(rawJson));
  }
}

Future<void> saveMembersToLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String rawJson = jsonEncode(globalMembersList);
  await prefs.setString('natt_members', rawJson);
}

Future<void> loadMembersFromLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String? rawJson = prefs.getString('natt_members');
  if (rawJson != null) {
    globalMembersList = List<Map<String, dynamic>>.from(jsonDecode(rawJson));
  }
}

// Déclaration de la variable avec la bonne structure
Map<String, List<Map<String, String>>> globalCalendarsMap = {};

Future<void> saveCalendarsToLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String rawJson = jsonEncode(globalCalendarsMap);
  await prefs.setString('natt_calendars', rawJson);
}

Future<void> loadCalendarsFromLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String? rawJson = prefs.getString('natt_calendars');
  if (rawJson != null) {
    Map<String, dynamic> decoded = jsonDecode(rawJson);
    globalCalendarsMap = decoded.map((key, value) {
      List<dynamic> list = value as List;
      return MapEntry(
        key,
        list.map((item) => Map<String, String>.from(item as Map)).toList(),
      );
    });
  }
}

// --- ALGORITHME D'EXPORTATION DU RAPPORT FINANCIER ---
Future<String> exportFinancialReport() async {
  final prefs = await SharedPreferences.getInstance();

  // 1. Calculs des données globales en arrière-plan
  int totalCaisse = 0;
  int totalAttendu = 0;
  int totalPaye = 0;

  StringBuffer buffer = StringBuffer();
  buffer.writeln('===========================================');
  buffer.writeln('        RAPPORT FINANCIER - NATT APP       ');
  buffer.writeln('        Généré le : ${DateTime.now().toLocal()}       ');
  buffer.writeln('===========================================\n');

  buffer.writeln('--- BILAN DES TONTINES ---');
  for (var tontine in globalTontinesList) {
    final tName = tontine['nom'] ?? 'Inconnue';
    String amountText = tontine['montant'] ?? '0';
    int montantNum =
        int.tryParse(amountText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    int caisseTontine = 0;
    int membresTontine = 0;

    for (var member in globalMembersList) {
      final List<dynamic> tLists = member['tontines'] is List
          ? member['tontines']
          : [];
      if (tLists.contains(tName)) {
        membresTontine++;
        totalAttendu++;
        if (member['status_$tName'] == 'À jour') {
          totalPaye++;
          caisseTontine += montantNum;
          totalCaisse += montantNum;
        }
      }
    }
    buffer.writeln(
      '• Tontine: $tName | Cotisation: $amountText | Membres: $membresTontine',
    );
    buffer.writeln('  Fonds collectés: $caisseTontine FCFA\n');
  }

  buffer.writeln('===========================================');
  buffer.writeln('--- ÉTAT DES COTISATIONS PAR MEMBRE ---');
  for (var member in globalMembersList) {
    buffer.writeln('👤 Membre: ${member['nom']} (${member['telephone']})');
    final List<dynamic> tLists = member['tontines'] is List
        ? member['tontines']
        : [];

    if (tLists.isEmpty) {
      buffer.writeln('  Status: Inscrit à aucune tontine');
    } else {
      for (var tName in tLists) {
        String status = member['status_$tName'] ?? 'En attente';
        String tx = member['tx_$tName'] ?? 'Aucune';
        buffer.writeln('  -> Tontine: $tName | Statut: $status | Réf: $tx');
      }
    }
    buffer.writeln('');
  }

  buffer.writeln('===========================================');
  buffer.writeln('--- APERÇU GLOBAL FINANCIER ---');
  buffer.writeln('💰 Total des fonds collectés : $totalCaisse FCFA');
  double taux = totalAttendu > 0 ? (totalPaye / totalAttendu) * 100 : 0.0;
  buffer.writeln(
    '📈 Taux de recouvrement global : ${taux.toStringAsFixed(1)} %\n',
  );
  buffer.writeln('===========================================');

  // 2. Simulation d'écriture sur fichier local pour le prototype
  // On sauvegarde une copie texte dans SharedPreferences pour l'historique d'export
  await prefs.setString('natt_last_printed_report', buffer.toString());

  return buffer.toString();
}

// Mémorise la date brute du dernier tirage par tontine : { 'NomTontine': '2026-09-23...' }
Map<String, String> globalLastDrawDatesMap = {};

Future<void> saveLastDrawDatesToLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String rawJson = jsonEncode(globalLastDrawDatesMap);
  await prefs.setString('natt_last_draw_dates', rawJson);
}

Future<void> loadLastDrawDatesFromLocal() async {
  final prefs = await SharedPreferences.getInstance();
  String? rawJson = prefs.getString('natt_last_draw_dates');
  if (rawJson != null) {
    globalLastDrawDatesMap = Map<String, String>.from(jsonDecode(rawJson));
  }
}

//Stockage dynamique des identifiants et informations de l'administrateur
String globalAdminIdentifier = '';
String globalAdminPassword = '';
String globalAdminName = ''; // ◄ NOUVEAU : Mémorise le nom réel de l'admin

Future<void> saveAdminCredentialsToLocal() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('natt_admin_id', globalAdminIdentifier);
  await prefs.setString('natt_admin_pass', globalAdminPassword);
  await prefs.setString(
    'natt_admin_name',
    globalAdminName,
  ); // Sauvegarde du nom
}

Future<void> loadAdminCredentialsFromLocal() async {
  final prefs = await SharedPreferences.getInstance();
  globalAdminIdentifier = prefs.getString('natt_admin_id') ?? '';
  globalAdminPassword = prefs.getString('natt_admin_pass') ?? '';
  globalAdminName =
      prefs.getString('natt_admin_name') ?? ''; // Chargement du nom
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NattApp());
}

class NattApp extends StatelessWidget {
  const NattApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Natt - Gestion de Tontines',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 1. ÉCRAN DE CONNEXION AVEC REDIRECTION INSCRIPTION
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    loadTontinesFromLocal().then((_) => setState(() {}));
    loadMembersFromLocal().then((_) => setState(() {}));
    loadAdminCredentialsFromLocal().then((_) => setState(() {}));
    loadLastDrawDatesFromLocal().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    String input = _identifierController.text.trim().replaceAll(' ', '');
    String password = _passwordController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un numéro ou identifiant correct.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir le bon mot de passe.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 1. VÉRIFICATION DYNAMIQUE DE L'ADMINISTRATEUR
    if (globalAdminIdentifier.isNotEmpty &&
        input.toLowerCase() == globalAdminIdentifier.toLowerCase()) {
      if (password == globalAdminPassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez saisir le bon mot de passe .'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // 2. VÉRIFICATION DU COMPTE MEMBRE
    final memberFound = globalMembersList.firstWhere(
      (m) => m['telephone'].toString().trim().replaceAll(' ', '') == input,
      orElse: () => {},
    );

    if (memberFound.isNotEmpty) {
      String savedPassword = memberFound['password'] ?? '';
      if (savedPassword.isNotEmpty && savedPassword != password) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('mot de pass incorrect.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      currentConnectedMember = memberFound;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MemberDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identifiant inconnu. Veuillez créer un compte .'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F4C5C), Color(0xFF0A192F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 190,
                      width: 190,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFE0A96D,
                            ).withValues(alpha: 0.15),
                            blurRadius: 35,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://stockake.com',
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE0A96D),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.blur_circular_rounded,
                              size: 85,
                              color: Color(0xFFE0A96D),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Natt',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bienvenue sur votre app de tontine',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  const Text(
                    'Numéro de téléphone ou identifiant',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _identifierController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      hintText: 'Ex: 77 437 84 84 ou admin',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white70,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'mot de passe',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      hintText: '•••••',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white70,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0A96D),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // NOUVEAU : LIEN VERS LA CRÉATION DE COMPTE
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Pas de compte?Créez votre compte ici',
                      style: TextStyle(
                        color: Color(0xFFE0A96D),
                        fontWeight: FontWeight.bold,
                      ),
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

// ==========================================
// 1B. INTERFACE : CRÉATION DE COMPTE (AVEC NOM ADMIN ET MAIL MEMBRE)
// ==========================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _extraFieldController =
      TextEditingController(); // ◄ NOUVEAU : Gère le nom (admin) ou le mail (membre)

  String _selectedRole = 'membre';
  final bool _obscureText = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _extraFieldController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    String identifier = _identifierController.text.trim().replaceAll(' ', '');
    String password = _passwordController.text.trim();
    String confirm = _confirmPasswordController.text.trim();
    String extraValue = _extraFieldController.text.trim();

    if (identifier.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty ||
        extraValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs avant de valider.'),
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les codes secrets de confirmation ne correspondent pas.',
          ),
        ),
      );
      return;
    }

    // ==========================================
    // CAS 1 : ENREGISTREMENT ADMINISTRATEUR
    // ==========================================
    if (_selectedRole == 'admin') {
      setState(() {
        globalAdminIdentifier = identifier;
        globalAdminPassword = password;
        globalAdminName = extraValue; // Enregistre le nom saisi
      });

      await saveAdminCredentialsToLocal();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Succès ! Le compte de l\'admin $globalAdminName a été configuré.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context);
      return;
    }

    // ==========================================
    // CAS 2 : ENREGISTREMENT MEMBRE
    // ==========================================
    int memberIndex = globalMembersList.indexWhere(
      (m) => m['telephone'].toString().trim().replaceAll(' ', '') == identifier,
    );

    if (memberIndex != -1) {
      setState(() {
        globalMembersList[memberIndex]['password'] = password;
        globalMembersList[memberIndex]['email'] =
            extraValue; // lie l'email saisi à la fiche du membre
      });

      await saveMembersToLocal();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Identité validée ! Bienvenue ${globalMembersList[memberIndex]['nom']}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_person_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Inscription refusée'),
            ],
          ),
          content: const Text(
            'Ce numéro de téléphone membre n\'a pas encore été répertorié par l\'administrateur de la tontine Natt.\n\nVeuillez demander à votre gestionnaire de vous ajouter avant d\'activer cet espace.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte Natt'),
        backgroundColor: const Color(0xFF0F4C5C),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0A192F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choisissez votre type de compte :',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // ONGLETS DE SÉLECTION DU RÔLE
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedRole = 'membre';
                            _extraFieldController.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'membre'
                                  ? const Color(0xFFE0A96D)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedRole == 'membre'
                                    ? const Color(0xFFE0A96D)
                                    : Colors.white24,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: _selectedRole == 'membre'
                                      ? const Color(0xFF0A192F)
                                      : Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Membre',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedRole == 'membre'
                                        ? const Color(0xFF0A192F)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedRole = 'admin';
                            _extraFieldController.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'admin'
                                  ? const Color(0xFFE0A96D)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedRole == 'admin'
                                    ? const Color(0xFFE0A96D)
                                    : Colors.white24,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: _selectedRole == 'admin'
                                      ? const Color(0xFF0A192F)
                                      : Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Administrateur',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedRole == 'admin'
                                        ? const Color(0xFF0A192F)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40, color: Colors.white24),

                  // CHAMP 1 : IDENTIFIANT DYNAMIQUE
                  Text(
                    _selectedRole == 'admin'
                        ? 'Identifiant ou pseudo Admin'
                        : 'Votre numéro de téléphone membre',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _identifierController,
                    keyboardType: _selectedRole == 'membre'
                        ? TextInputType.phone
                        : TextInputType.text,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      hintText: _selectedRole == 'admin'
                          ? 'Ex: AdminNatt'
                          : 'Ex: 77 123 45 67',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🚨 CHAMP 2 NOUVEAU ET DYNAMIQUE : NOM COMPLET OU EMAIL
                  Text(
                    _selectedRole == 'admin'
                        ? 'Votre Nom complet'
                        : 'Votre adresse Email',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _extraFieldController,
                    keyboardType: _selectedRole == 'membre'
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      hintText: _selectedRole == 'admin'
                          ? 'Ex: Modou Diop'
                          : 'Ex: membre@natt.sn',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Définir un Code Secret',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      hintText: '•••••',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Confirmer le Code Secret',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureText,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      hintText: '•••••',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0A96D),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selectedRole == 'admin'
                          ? 'Créer mon espace Admin'
                          : 'Activer mon espace Membre',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

// ==========================================
// 2. ÉCRAN TABLEAU DE BORD - ADMINISTRATEUR
// ==========================================
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Espace Administrateur',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue, ${globalAdminName.isEmpty ? "Administrateur" : globalAdminName}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    Icons.account_balance_wallet_rounded,
                    'Tontines',
                    Colors.teal,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TontineManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    Icons.people_alt_rounded,
                    'Membres',
                    Colors.blue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MemberManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    Icons.check_circle_outline_rounded,
                    'Valider Paiements',
                    Colors.orange,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ValidatePaymentsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    Icons.bar_chart_rounded,
                    'Statistiques',
                    Colors.purple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminStatsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2B. SOUS-MENU : GESTION DES TONTINES
// ==========================================
class TontineManagementScreen extends StatelessWidget {
  const TontineManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Tontines',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt_rounded, color: Colors.teal),
              title: const Text(
                'Liste des tontines',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TontineListScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_box_rounded, color: Colors.teal),
              title: const Text(
                'Créer une tontine',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateTontineScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.edit_note_rounded,
                color: Colors.orange,
              ),
              title: const Text(
                'Modifier tontine',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditTontineScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
              ),
              title: const Text(
                'Supprimer tontine',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeleteTontineScreen(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.casino_rounded, color: Colors.purple),
              title: const Text(
                'Lancer un tirage au sort',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDrawScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2C. SOUS-MENU : GESTION DES MEMBRES (MIS À JOUR)
// ==========================================
class MemberManagementScreen extends StatelessWidget {
  const MemberManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Membres',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.blue,
              ),
              title: const Text(
                'Ajouter un membre',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMemberScreen(),
                  ),
                );
              },
            ),
          ),
          // ==========================================
          // 💰 NOUVELLE OPTION : CAISSE SOCIALE LIBRE
          // ==========================================
          Card(
            child: ListTile(
              leading: const Icon(Icons.handshake_rounded, color: Colors.teal),
              title: const Text(
                'Cotisation Sociale Libre',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Enregistrer un versement volontaire d\'un membre',
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // Déclenchement du dialogue de sélection globale
                _showGlobalSocialPaymentDialog(context);
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.person_remove_rounded,
                color: Colors.red,
              ),
              title: const Text(
                'Supprimer un membre',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemoveMemberScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.layers_rounded, color: Colors.purple),
              title: const Text(
                'Participer à une ou plusieurs tontines',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssignTontineScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // NOUVEAU BOUTON : Liste des membres par tontine
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.assignment_ind_rounded,
                color: Colors.teal,
              ),
              title: const Text(
                'Membres par tontine',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TontineMembersListScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. TABLEAU DE BORD MEMBRE (AVEC BARRE DE NAVIGATION)
// ==========================================
class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  int _currentIndex = 0; // 0 = Accueil, 1 = Profil

  // Liste des deux sous-écrans de l'espace membre
  final List<Widget> _screens = [
    const MemberHomeTab(),
    const MemberProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(
          0xFF0F4C5C,
        ), // Bleu canard de votre charte
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// L'ancien contenu du tableau de bord devient le premier onglet (Accueil)
class MemberHomeTab extends StatelessWidget {
  const MemberHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final String nomMembre = currentConnectedMember?['nom'] ?? 'Membre';
    final List<dynamic> tontinesInscrites =
        currentConnectedMember?['tontines'] is List
        ? currentConnectedMember!['tontines']
        : [];

    bool aUnRetard = false;
    for (var tontine in tontinesInscrites) {
      if (currentConnectedMember?['status_$tontine'] == 'En retard') {
        aUnRetard = true;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Espace de $nomMembre',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F4C5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue, $nomMembre 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              color: aUnRetard ? Colors.red.shade50 : Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      aUnRetard ? Icons.warning_amber_rounded : Icons.stars,
                      color: aUnRetard ? Colors.red : Colors.teal,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statut de vos cotisations',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            tontinesInscrites.isEmpty
                                ? 'Non inscrit à une tontine'
                                : (aUnRetard
                                      ? 'Vous avez des retards de paiement !'
                                      : 'À jour dans vos cotisations'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: aUnRetard
                                  ? Colors.red.shade700
                                  : Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_month,
                      color: Color(0xFF0F4C5C),
                    ),
                    title: const Text('Calendrier des versements'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TontineCalendarScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF0F4C5C),
                    ),
                    title: const Text('Mon historique de paiements'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4A. INTERFACE : CRÉER UNE TONTINE
// ==========================================
class CreateTontineScreen extends StatefulWidget {
  const CreateTontineScreen({super.key});

  @override
  State<CreateTontineScreen> createState() => _CreateTontineScreenState();
}

class _CreateTontineScreenState extends State<CreateTontineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _membersCountController = TextEditingController();
  final _socialCotisationController = TextEditingController();
  String _selectedFrequency = 'Mensuelle';

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _membersCountController.dispose();
    _socialCotisationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Créer une Tontine',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la tontine',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Veuillez saisir un nom' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant de la cotisation (FCFA)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Veuillez saisir un montant' : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Montant Cotisation Caisse Sociale (FCFA)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _socialCotisationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Ex: 1000",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.handshake_rounded,
                      color: Colors.teal,
                    ),
                  ),
                ),
                TextFormField(
                  controller: _membersCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre maximum de membres',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  validator: (value) => value!.isEmpty
                      ? 'Veuillez saisir le nombre de membres'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Fréquence des versements',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Hebdomadaire', 'Mensuelle'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedFrequency = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final tontineName = _nameController.text.trim();

                      globalTontinesList.add({
                        'nom': _nameController.text,
                        'montant': '${_amountController.text} FCFA',
                        'frequence': _selectedFrequency,
                        'membres':
                            '0 / ${_membersCountController.text} membres',
                        'status': 'En attente',
                        'social_cotisation':
                            _socialCotisationController.text.trim().isEmpty
                            ? '0'
                            : _socialCotisationController.text.trim(),
                        'social_caisse_total': '0', // Démarre sagement à 0 FCFA
                      });
                      globalCalendarsMap[tontineName] = <Map<String, String>>[];
                      await saveTontinesToLocal();
                      await saveCalendarsToLocal(); // Sauvegarde de la structure du calendrier
                      await saveTontinesToLocal();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tontine "${_nameController.text}" enregistrée !',
                          ),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Enregistrer la tontine',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4B. INTERFACE : LISTE DES TONTINES (CLÔTURE AUTOMATIQUE COMPTEUR)
// ==========================================
class TontineListScreen extends StatefulWidget {
  const TontineListScreen({super.key});

  @override
  State<TontineListScreen> createState() => _TontineListScreenState();
}

class _TontineListScreenState extends State<TontineListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Tontines'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: globalTontinesList.isEmpty
          ? const Center(child: Text('Aucune tontine créée.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: globalTontinesList.length,
              itemBuilder: (context, index) {
                final tontine = globalTontinesList[index];
                final String tontineName = tontine['nom'] ?? 'Inconnue';
                String status = tontine['status'] ?? 'En attente';

                // --- ALGORITHME DE CORRECTION ET CLÔTURE AUTOMATIQUE EN TEMPS RÉEL ---
                final List<dynamic> currentCalendar =
                    globalCalendarsMap[tontineName] ?? [];

                // On récupère le nombre total de membres inscrits à cette tontine précise
                final int totalInscrits = globalMembersList.where((m) {
                  final List<dynamic> tLists = m['tontines'] is List
                      ? m['tontines']
                      : [];
                  return tLists.contains(tontineName);
                }).length;

                // LOGIQUE : Si tous les membres inscrits ont été tirés au sort, la tontine passe d'office en "Clôturée"
                if (totalInscrits > 0 &&
                    currentCalendar.length >= totalInscrits &&
                    status == 'Active') {
                  status = 'Clôturée';
                  globalTontinesList[index]['status'] = 'Clôturée';
                  saveTontinesToLocal(); // On synchronise immédiatement SharedPreferences
                }

                // Couleurs dynamiques des étiquettes de statut
                Color badgeColor = Colors.orange;
                if (status == 'Active') badgeColor = Colors.green;
                if (status == 'Clôturée') badgeColor = Colors.purple;
                if (status == 'Désactivée') badgeColor = Colors.red;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tontineName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: badgeColor),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cotisation : ${tontine['montant']} (${tontine['frequence']})',
                        ),
                        Text('Quota : ${tontine['membres']}'),
                        Text(
                          'Cotisation Sociale : ${tontine['social_cotisation'] ?? '0'} FCFA / tour',
                        ),
                        Text(
                          '💰 Solde Caisse Sociale : ${tontine['social_caisse_total'] ?? '0'} FCFA',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),

                        // ÉTAT 1 : EN ATTENTE (Bouton d'activation)
                        if (status == 'En attente') ...[
                          const Divider(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                setState(() {
                                  globalTontinesList[index]['status'] =
                                      'Active';
                                });
                                await saveTontinesToLocal();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'La tontine "$tontineName" est désormais Active ! 🚀',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Activer la tontine'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],

                        // ÉTAT 2 : CLÔTURÉE (Boutons magiques de Renouvellement / Désactivation)
                        if (status == 'Clôturée') ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              // Bouton de désactivation définitive (Archivage invisible)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    setState(() {
                                      globalTontinesList[index]['status'] =
                                          'Désactivée';
                                    });
                                    await saveTontinesToLocal();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Tontine "$tontineName" archivée et désactivée.',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.block,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Désactiver',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Bouton de Renouvellement (Remet le calendrier à zéro mais conserve l'équipe !)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    setState(() {
                                      globalTontinesList[index]['status'] =
                                          'Active';
                                      globalCalendarsMap.remove(tontineName);
                                      globalCalendarsMap[tontineName] =
                                          <Map<String, String>>[];
                                      globalLastDrawDatesMap.remove(
                                        tontineName,
                                      );

                                      for (var member in globalMembersList) {
                                        final List<dynamic> tLists =
                                            member['tontines'] is List
                                            ? member['tontines']
                                            : [];
                                        if (tLists.contains(tontineName)) {
                                          member['status_$tontineName'] =
                                              'En attente';
                                          member.remove('tx_$tontineName');
                                        }
                                      }
                                    });

                                    await saveTontinesToLocal();
                                    await saveCalendarsToLocal();
                                    await saveLastDrawDatesToLocal();
                                    await saveMembersToLocal();

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '🎉 La tontine "$tontineName" a été renouvelée pour un nouveau cycle !',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Renouveler'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 4C. INTERFACE : MODIFIER UNE TONTINE
// ==========================================
class EditTontineScreen extends StatefulWidget {
  const EditTontineScreen({super.key});

  @override
  State<EditTontineScreen> createState() => _EditTontineScreenState();
}

class _EditTontineScreenState extends State<EditTontineScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier une Tontine'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: globalTontinesList.isEmpty
          ? const Center(child: Text('Aucune tontine à modifier.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: globalTontinesList.length,
              itemBuilder: (context, index) {
                final tontine = globalTontinesList[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.edit, color: Colors.orange),
                    title: Text(tontine['nom']!),
                    subtitle: Text('Cotisation : ${tontine['montant']}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => TontineEditDialog(
                          index: index,
                          onSave: () {
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class TontineEditDialog extends StatefulWidget {
  final int index;
  final VoidCallback onSave;
  const TontineEditDialog({
    super.key,
    required this.index,
    required this.onSave,
  });

  @override
  State<TontineEditDialog> createState() => _TontineEditDialogState();
}

class _TontineEditDialogState extends State<TontineEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _membersCountController;
  late String _dialogueFrequency;

  @override
  void initState() {
    super.initState();
    // 1. Récupération propre du nom et du montant
    _nameController = TextEditingController(
      text: globalTontinesList[widget.index]['nom'],
    );
    _amountController = TextEditingController(
      text: (globalTontinesList[widget.index]['montant'] ?? '')
          .toString()
          .replaceAll(' FCFA', ''),
    );

    // 2. CORRECTION DU BUG : Extraction propre et sécurisée du nombre maximum de membres
    String currentMaxMembers = '10';
    dynamic membresValue = globalTontinesList[widget.index]['membres'];

    if (membresValue != null) {
      String membresText = membresValue
          .toString(); // On force la conversion en String pour éviter le bug de List
      final parts = membresText.split(' / ');
      if (parts.length > 1) {
        currentMaxMembers = parts[1].replaceAll(' membres', '');
      }
    }

    _membersCountController = TextEditingController(text: currentMaxMembers);
    _dialogueFrequency =
        globalTontinesList[widget.index]['frequence'] ?? 'Mensuelle';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _membersCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier les informations'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom de la tontine'),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _membersCountController,
              decoration: const InputDecoration(
                labelText: 'Nombre max de membres',
              ),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              initialValue: _dialogueFrequency,
              items: [
                'Hebdomadaire',
                'Mensuelle',
              ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) {
                setState(() {
                  _dialogueFrequency = v!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () async {
            globalTontinesList[widget.index]['nom'] = _nameController.text;
            globalTontinesList[widget.index]['montant'] =
                '${_amountController.text} FCFA';
            globalTontinesList[widget.index]['frequence'] = _dialogueFrequency;
            globalTontinesList[widget.index]['membres'] =
                '0 / ${_membersCountController.text} membres';
            await saveTontinesToLocal();
            widget.onSave();
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }
}

// ==========================================
// 4D. INTERFACE : SUPPRIMER UNE TONTINE
// ==========================================
class DeleteTontineScreen extends StatefulWidget {
  const DeleteTontineScreen({super.key});

  @override
  State<DeleteTontineScreen> createState() => _DeleteTontineScreenState();
}

class _DeleteTontineScreenState extends State<DeleteTontineScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer une Tontine'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: globalTontinesList.isEmpty
          ? const Center(child: Text('Aucune tontine à supprimer.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: globalTontinesList.length,
              itemBuilder: (context, index) {
                final tontine = globalTontinesList[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: Text(tontine['nom']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        setState(() {
                          globalTontinesList.removeAt(index);
                        });
                        await saveTontinesToLocal();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 4E. INTERFACE : AJOUTER UN MEMBRE
// ==========================================
class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Membre'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom et Prénom',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Téléphone requis' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    globalMembersList.add({
                      'nom': _nameController.text,
                      'telephone': _phoneController.text,
                      'tontines': <String>[],
                      'status': 'Actif',
                    });
                    await saveMembersToLocal();
                    if (!mounted) return;
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Enregistrer le membre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4F. INTERFACE : SUPPRIMER UN MEMBRE
// ==========================================
class RemoveMemberScreen extends StatefulWidget {
  const RemoveMemberScreen({super.key});

  @override
  State<RemoveMemberScreen> createState() => _RemoveMemberScreenState();
}

class _RemoveMemberScreenState extends State<RemoveMemberScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer un Membre'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: globalMembersList.isEmpty
          ? const Center(child: Text('Aucun membre disponible.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: globalMembersList.length,
              itemBuilder: (context, index) {
                final member = globalMembersList[index];
                return Card(
                  child: ListTile(
                    title: Text(member['nom']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        setState(() {
                          globalMembersList.removeAt(index);
                        });
                        await saveMembersToLocal();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 4G. INTERFACE : AFFECTATION AVEC CONTRÔLE DE QUOTA ET D'ACTIVATION (MIS À JOUUR)
class AssignTontineScreen extends StatefulWidget {
  const AssignTontineScreen({super.key});

  @override
  State<AssignTontineScreen> createState() => _AssignTontineScreenState();
}

class _AssignTontineScreenState extends State<AssignTontineScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Affecter aux Tontines'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: globalMembersList.isEmpty
          ? const Center(child: Text('Aucun membre disponible.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: globalMembersList.length,
              itemBuilder: (context, index) {
                final member = globalMembersList[index];
                final List<dynamic> memberTontines = member['tontines'] is List
                    ? member['tontines']
                    : [];
                final tontinesText = memberTontines.isEmpty
                    ? 'Aucune tontine'
                    : memberTontines.join(', ');

                return Card(
                  child: ListTile(
                    title: Text(
                      member['nom']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Tontines : $tontinesText'),
                    trailing: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.purple,
                    ),
                    onTap: () {
                      _showAssignDialog(context, index);
                    },
                  ),
                );
              },
            ),
    );
  }

  void _showAssignDialog(BuildContext context, int memberIndex) {
    if (globalTontinesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Créez d\'abord une tontine.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inscrire ${globalMembersList[memberIndex]['nom']}'),
        content: const Text('Choisir une tontine :'),
        actions: globalTontinesList.map((tontine) {
          final List<dynamic> currentTontines =
              globalMembersList[memberIndex]['tontines'] is List
              ? globalMembersList[memberIndex]['tontines']
              : [];
          final String status = tontine['status'] ?? 'En attente';
          if (status == 'Désactivée' || status == 'Clôturée') {
            return const SizedBox.shrink();
          }
          int inscritsActuels = globalMembersList.where((m) {
            final List<dynamic> tLists = m['tontines'] is List
                ? m['tontines']
                : [];
            return tLists.contains(tontine['nom']);
          }).length;

          int maxPermis = 10;
          if (tontine['membres'] != null) {
            final parts = tontine['membres'].toString().split(' / ');
            if (parts.length > 1) {
              maxPermis =
                  int.tryParse(parts[1].replaceAll(' membres', '').trim()) ??
                  10;
            }
          }

          bool estPleine = inscritsActuels >= maxPermis;

          if (currentTontines.contains(tontine['nom'])) {
            return const SizedBox.shrink();
          }

          return TextButton(
            // Le bouton est bloqué ONLY si la tontine est pleine
            onPressed: estPleine
                ? null
                : () async {
                    setState(() {
                      if (globalMembersList[memberIndex]['tontines'] is! List) {
                        globalMembersList[memberIndex]['tontines'] = <String>[];
                      }
                      globalMembersList[memberIndex]['tontines'].add(
                        tontine['nom'],
                      );
                      globalMembersList[memberIndex]['status_${tontine['nom']}'] =
                          'En attente';
                      tontine['membres'] =
                          '${inscritsActuels + 1} / $maxPermis membres';
                    });

                    await saveMembersToLocal();
                    await saveTontinesToLocal();

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Membre inscrit avec succès !'),
                      ),
                    );
                  },
            child: Text(
              estPleine
                  ? '${tontine['nom']} (Complet !)'
                  : '${tontine['nom']} ($inscritsActuels/$maxPermis) [${status.toUpperCase()}]',
              style: TextStyle(color: estPleine ? Colors.grey : Colors.purple),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// 4H. INTERFACE : SUIVI DES COTISATIONS ET SUPPRESSION (CORRIGÉE)
// ==========================================
class ValidatePaymentsScreen extends StatefulWidget {
  const ValidatePaymentsScreen({super.key});

  @override
  State<ValidatePaymentsScreen> createState() => _ValidatePaymentsScreenState();
}

class _ValidatePaymentsScreenState extends State<ValidatePaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> participationRows = [];

    // Construction de la liste à partir des données partagées en temps réel
    for (var member in globalMembersList) {
      final List<dynamic> memberTontines = member['tontines'] is List
          ? member['tontines']
          : [];
      for (var tontineName in memberTontines) {
        final tontineData = globalTontinesList.firstWhere(
          (t) => t['nom'] == tontineName,
          orElse: () => {'montant': '0 FCFA'},
        );

        String txKey = 'tx_$tontineName';
        String currentTx = member[txKey] ?? '';

        participationRows.add({
          'memberRef': member,
          'nom': member['nom'],
          'tontine': tontineName,
          'montant': tontineData['montant'],
          'statusKey': 'status_$tontineName',
          'transaction': currentTx,
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des Cotisations'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: participationRows.isEmpty
          ? const Center(child: Text('Aucune inscription enregistrée.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: participationRows.length,
              itemBuilder: (context, index) {
                final row = participationRows[index];
                final memberMap = row['memberRef'] as Map<String, dynamic>;
                final String currentStatus =
                    memberMap[row['statusKey']] ?? 'En attente';
                final isPaid = currentStatus == 'À jour';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              row['nom']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              row['montant']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tontine : ${row['tontine']}',
                          style: const TextStyle(color: Colors.grey),
                        ),

                        // Affichage du reçu automatique si disponible
                        if (row['transaction'].toString().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6, bottom: 4),
                            padding: const EdgeInsets.all(6),
                            color: Colors.blue.shade50,
                            width: double.infinity,
                            child: Text(
                              '💳 Réf Reçu : ${row['transaction']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Indicateur visuel du statut
                            Row(
                              children: [
                                Icon(
                                  isPaid
                                      ? Icons.check_circle
                                      : Icons.pending_actions_rounded,
                                  color: isPaid ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Statut : $currentStatus',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),

                            // BOUTON SUPPRIMER RE-PLACÉ ICI DE FAÇON PERMANENTE
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Supprimer cette participation',
                              onPressed: () async {
                                _showCancelDialog(
                                  context,
                                  memberMap,
                                  row['tontine'],
                                  row['statusKey'],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    Map<String, dynamic> member,
    String tontineName,
    String statusKey,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la ligne ?'),
        content: Text(
          'Voulez-vous désinscrire ${member['nom']} de la tontine "$tontineName" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              setState(() {
                if (member['tontines'] is List) {
                  member['tontines'].remove(tontineName);
                }
                member.remove(statusKey);
                member.remove('tx_$tontineName');
              });
              await saveMembersToLocal();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4I. INTERFACE : STATISTIQUES FINANCIÈRES
// ==========================================
class AdminStatsScreen extends StatelessWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    int totalCaisseGlobale = 0;
    int totalCotisationsAttendues = 0;
    int totalCotisationsPayees = 0;
    Map<String, Map<String, int>> tontineStats = {};

    for (var tontine in globalTontinesList) {
      final tontineName = tontine['nom'] ?? 'Inconnue';
      int montantNum =
          int.tryParse(
            (tontine['montant'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      tontineStats[tontineName] = {
        'caisse': 0,
        'attendue': 0,
        'montantUnitaire': montantNum,
      };
    }

    for (var member in globalMembersList) {
      final List<dynamic> memberTontines = member['tontines'] is List
          ? member['tontines']
          : [];
      for (var tontineName in memberTontines) {
        if (tontineStats.containsKey(tontineName)) {
          int montant = tontineStats[tontineName]!['montantUnitaire']!;
          totalCotisationsAttendues++;
          tontineStats[tontineName]!['attendue'] =
              tontineStats[tontineName]!['attendue']! + 1;
          if (member['status_$tontineName'] == 'À jour') {
            totalCotisationsPayees++;
            totalCaisseGlobale += montant;
            tontineStats[tontineName]!['caisse'] =
                tontineStats[tontineName]!['caisse']! + montant;
          }
        }
      }
    }

    double tauxGlobal = totalCotisationsAttendues > 0
        ? (totalCotisationsPayees / totalCotisationsAttendues) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques Financières'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.purple.shade50,
              child: ListTile(
                title: const Text('Fonds Collectés'),
                trailing: Text(
                  '$totalCaisseGlobale FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.purple,
                  ),
                ),
              ),
            ),
            // Insérer ce bloc juste avant le "const SizedBox(height: 16)," et le "Expanded(" dans AdminStatsScreen :
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Déclenchement de l'algorithme d'exportation
                  String reportText = await exportFinancialReport();

                  // Affichage d'une boîte de dialogue avec l'aperçu du fichier généré
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(
                            Icons.file_download_done,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          const Text('Rapport Exporté !'),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Le fichier "rapport_natt.txt" a été généré avec succès dans le système.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.grey.shade100,
                              child: Text(
                                reportText,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Fermer'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Exporter le rapport financier (.TXT)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Taux Global'),
                        Text('${tauxGlobal.toStringAsFixed(1)} %'),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: tauxGlobal / 100,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: tontineStats.keys.length,
                itemBuilder: (context, idx) {
                  String name = tontineStats.keys.elementAt(idx);
                  var s = tontineStats[name]!;
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text(
                        'À jour : ${s['caisse']! ~/ s['montantUnitaire']!} / ${s['attendue']!}',
                      ),
                      trailing: Text('${s['caisse']!} F'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4K. INTERFACE : LISTE DES MEMBRES PAR TONTINE
// ==========================================
class TontineMembersListScreen extends StatelessWidget {
  const TontineMembersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres par Tontine'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: globalTontinesList.isEmpty
          ? const Center(child: Text('Aucune tontine créée pour le moment.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: globalTontinesList.length,
              itemBuilder: (context, index) {
                final tontine = globalTontinesList[index];
                final tontineName = tontine['nom']!;

                // Algorithme de filtrage : On cherche les membres inscrits à cette tontine précise
                final listInscrits = globalMembersList.where((member) {
                  final List<dynamic> tLists = member['tontines'] is List
                      ? member['tontines']
                      : [];
                  return tLists.contains(tontineName);
                }).toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête de la tontine
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tontineName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              '${listInscrits.length} inscrit(s)',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Affichage conditionnel des membres
                        if (listInscrits.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Aucun membre inscrit dans ce groupe.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.orange,
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap:
                                true, // Permet d'imbriquer une liste dans une autre
                            physics:
                                const NeverScrollableScrollPhysics(), // Évite les conflits de défilement
                            itemCount: listInscrits.length,
                            itemBuilder: (context, mIndex) {
                              final currentMember = listInscrits[mIndex];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade50,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  currentMember['nom']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  'Téléphone : ${currentMember['telephone']}',
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    currentMember['status_$tontineName'] ??
                                        'En attente',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 4J. INTERFACE : TIRAGE MENSUEL AVEC RÈGLE N-1 ET BLOCAGE DE 30 JOURS (ADMIN)
// ==========================================
class AdminDrawScreen extends StatefulWidget {
  const AdminDrawScreen({super.key});

  @override
  State<AdminDrawScreen> createState() => _AdminDrawScreenState();
}

class _AdminDrawScreenState extends State<AdminDrawScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tirage au sort Mensuel'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: globalTontinesList.isEmpty
          ? const Center(child: Text('Aucune tontine disponible.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: globalTontinesList.length,
              itemBuilder: (context, index) {
                // À mettre au tout début de l'itemBuilder de votre AdminDrawScreen :
                final tontine = globalTontinesList[index];
                if (tontine['status'] == 'Désactivée') {
                  return const SizedBox.shrink(); // Masque de façon invisible
                }
                final tontineName = tontine['nom']!;

                final allMembers = globalMembersList
                    .where(
                      (m) =>
                          (m['tontines'] is List &&
                          m['tontines'].contains(tontineName)),
                    )
                    .map((m) => m['nom'].toString())
                    .toList();

                if (!globalCalendarsMap.containsKey(tontineName)) {
                  globalCalendarsMap[tontineName] = [];
                }
                final List<Map<String, String>> currentCalendar =
                    globalCalendarsMap[tontineName]!;
                final List<String> dejaTires = currentCalendar
                    .map((item) => item['membre']!)
                    .toList();
                final List<String> membresRestants = allMembers
                    .where((m) => !dejaTires.contains(m))
                    .toList();

                int numeroMoisProchain = currentCalendar.length + 1;
                final bool ilResteUneSeulePersonne =
                    membresRestants.length == 1 && allMembers.length > 1;
                final bool tontineCloturee =
                    membresRestants.isEmpty && allMembers.isNotEmpty;

                // --- ALGORITHME DE CONTRÔLE CHRONOLOGIQUE DES 30 JOURS ---
                bool tempsAttenteRespecte = true;
                int joursRestants = 0;

                if (globalLastDrawDatesMap.containsKey(tontineName)) {
                  DateTime dernierTirage = DateTime.parse(
                    globalLastDrawDatesMap[tontineName]!,
                  );
                  DateTime maintenant = DateTime.now();

                  // Calcul de la différence en jours
                  int joursEcoules = maintenant
                      .difference(dernierTirage)
                      .inDays;

                  if (joursEcoules < 30) {
                    // AJUSTÉ ICI : 30 jours au lieu de 28
                    tempsAttenteRespecte = false;
                    joursRestants = 30 - joursEcoules;
                  }
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tontineName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Membres au total : ${allMembers.length} | Restants : ${membresRestants.length}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const Divider(height: 24),

                        if (currentCalendar.isNotEmpty) ...[
                          const Text(
                            '📅 Calendrier des bénéficiaires tirés :',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...currentCalendar.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item['membre']} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '➔ Reçoit le : ${item['date']}',
                                    style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Affichage du bandeau d'alerte si le délai des 30 jours n'est pas rempli
                        if (!tempsAttenteRespecte &&
                            !tontineCloturee &&
                            allMembers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_clock, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tirage verrouillé. Veuillez attendre encore $joursRestants jour(s) pour refaire un autre tirage.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (tontineCloturee)
                          const Text(
                            '🎉 Tous les membres de cette tontine ont leur tour assigné !',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else if (allMembers.isEmpty)
                          const Text(
                            '⏳ En attente d\'inscription de membres.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else if (ilResteUneSeulePersonne) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Il reste seulement ${membresRestants.first}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: !tempsAttenteRespecte
                                  ? null
                                  : () async {
                                      setState(() {
                                        String dernierMembre =
                                            membresRestants.first;
                                        DateTime dateBase = DateTime.now();
                                        DateTime dateVersement = DateTime(
                                          dateBase.year,
                                          dateBase.month +
                                              currentCalendar.length,
                                          dateBase.day,
                                        );
                                        String dateFormatee =
                                            '${dateVersement.day.toString().padLeft(2, '0')}/${dateVersement.month.toString().padLeft(2, '0')}/${dateVersement.year}';

                                        globalCalendarsMap[tontineName]!.add(
                                          Map<String, String>.from({
                                            'membre': dernierMembre,
                                            'date': dateFormatee,
                                            'tour': 'Mois $numeroMoisProchain',
                                          }),
                                        );

                                        globalLastDrawDatesMap[tontineName] =
                                            DateTime.now().toIso8601String();
                                      });

                                      await saveCalendarsToLocal();
                                      await saveLastDrawDatesToLocal();
                                    },
                              icon: const Icon(
                                Icons.assignment_turned_in_rounded,
                              ),
                              label: Text(
                                'Assigner automatiquement le Mois $numeroMoisProchain',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ] else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: !tempsAttenteRespecte
                                  ? null
                                  : () async {
                                      setState(() {
                                        List<String> pool = List.from(
                                          membresRestants,
                                        );
                                        pool.shuffle();
                                        String gagnantUnique = pool.first;

                                        DateTime dateBase = DateTime.now();
                                        DateTime dateVersement = DateTime(
                                          dateBase.year,
                                          dateBase.month +
                                              currentCalendar.length,
                                          dateBase.day,
                                        );
                                        String dateFormatee =
                                            '${dateVersement.day.toString().padLeft(2, '0')}/${dateVersement.month.toString().padLeft(2, '0')}/${dateVersement.year}';

                                        globalCalendarsMap[tontineName]!.add(
                                          Map<String, String>.from({
                                            'membre': gagnantUnique,
                                            'date': dateFormatee,
                                            'tour': 'Mois $numeroMoisProchain',
                                          }),
                                        );

                                        globalLastDrawDatesMap[tontineName] =
                                            DateTime.now().toIso8601String();
                                      });

                                      await saveCalendarsToLocal();
                                      await saveLastDrawDatesToLocal();

                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Mois $numeroMoisProchain attribué à ${globalCalendarsMap[tontineName]!.last['membre']} !',
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.casino),
                              label: Text(
                                'Tirer au sort le bénéficiaire du Mois $numeroMoisProchain',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 5A. INTERFACE : ORDRE ET DATES DE VERSEMENT (FILTRÉ PAR MEMBRE)
// ==========================================
class TontineCalendarScreen extends StatelessWidget {
  const TontineCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Récupération sécurisée des informations du membre connecté au système
    final String currentMemberName = currentConnectedMember?['nom'] ?? 'Membre';

    // 2. Récupération de la liste des tontines auxquelles ce membre est inscrit
    final List<dynamic> memberTontinesInscrites =
        currentConnectedMember?['tontines'] is List
        ? currentConnectedMember!['tontines']
        : [];

    // 3. ALGORITHME DE FILTRAGE : On ne garde que les tontines dont le membre fait partie
    final List<Map<String, dynamic>> myFilteredTontines = globalTontinesList
        .where((tontine) {
          return memberTontinesInscrites.contains(tontine['nom']);
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordre des Bénéficiaires'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: myFilteredTontines.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Vous n\'êtes inscrit à aucune tontine active pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount:
                  myFilteredTontines.length, // Utilisation de la liste filtrée
              itemBuilder: (context, index) {
                final tontine = myFilteredTontines[index];
                if (tontine['status'] == 'Désactivée') {
                  return const SizedBox.shrink();
                }

                final tontineName = tontine['nom']!;

                // Extraction de l'historique des tirages
                final List<Map<String, String>> currentCalendar =
                    globalCalendarsMap[tontineName] != null
                    ? List<Map<String, String>>.from(
                        globalCalendarsMap[tontineName]!,
                      )
                    : <Map<String, String>>[];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tontineName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        Text(
                          'Montant de la main : ${tontine['montant']}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(height: 20),

                        if (currentCalendar.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'L\'administrateur n\'a pas encore débuté les tirages mensuels pour ce groupe.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.orange,
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentCalendar.length,
                            itemBuilder: (context, cIndex) {
                              final drawItem = currentCalendar[cIndex];
                              final bool isMe =
                                  drawItem['membre'] == currentMemberName;
                              final bool isFirstMonth = cIndex == 0;

                              return Card(
                                color: isMe
                                    ? Colors.teal.shade50
                                    : Colors.white,
                                elevation: isMe ? 2 : 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: isMe
                                      ? const BorderSide(
                                          color: Colors.teal,
                                          width: 1.5,
                                        )
                                      : BorderSide.none,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isFirstMonth
                                        ? Colors.orangeAccent
                                        : (isMe
                                              ? Colors.teal
                                              : Colors.grey.shade200),
                                    foregroundColor: isFirstMonth || isMe
                                        ? Colors.white
                                        : Colors.black87,
                                    child: Text('${cIndex + 1}'),
                                  ),
                                  title: Text(
                                    drawItem['membre']! +
                                        (isMe ? ' (Vous)' : ''),
                                    style: TextStyle(
                                      fontWeight: isMe
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Date de versement : ${drawItem['date']}',
                                  ),
                                  trailing: isFirstMonth
                                      ? Chip(
                                          label: const Text(
                                            'Mois Prochain',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor:
                                              Colors.orange.shade100,
                                        )
                                      : (isMe
                                            ? const Icon(
                                                Icons.star,
                                                color: Colors.teal,
                                              )
                                            : null),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// 5B. INTERFACE : HISTORIQUE & PAIEMENT MOBILE (MEMBRE)
// ==========================================
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final String currentMemberName = currentConnectedMember?['nom'] ?? '';
    List<Map<String, dynamic>> myPayments = [];

    // On retrouve le membre dans la liste globale pour avoir ses données à jour
    int memberIndex = globalMembersList.indexWhere(
      (m) => m['nom'] == currentMemberName,
    );

    if (memberIndex != -1) {
      final member = globalMembersList[memberIndex];
      final List<dynamic> memberTontines = member['tontines'] is List
          ? member['tontines']
          : [];

      for (var tontineName in memberTontines) {
        final tontineData = globalTontinesList.firstWhere(
          (t) => t['nom'] == tontineName,
          orElse: () => {'montant': '0 FCFA'},
        );

        String statusKey = 'status_$tontineName';
        String currentStatus = member[statusKey] ?? 'En attente';
        String txKey = 'tx_$tontineName';
        String currentTx = member[txKey] ?? '';

        myPayments.add({
          'tontine': tontineName,
          'montant': tontineData['montant'],
          'statut': currentStatus,
          'transaction': currentTx,
          'memberIndex': memberIndex,
          'statusKey': statusKey,
          'txKey': txKey,
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Historique & Paiement'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: myPayments.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Aucune cotisation active.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myPayments.length,
              itemBuilder: (context, index) {
                final payment = myPayments[index];
                final String status = payment['statut'];
                final isPaid = status == 'À jour';
                final isPending = status == 'Vérification en cours';
                final isLate = status == 'En retard';

                Color statusColor = Colors.orange;
                IconData statusIcon = Icons.access_time_filled;
                if (isPaid) {
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle;
                }
                if (isPending) {
                  statusColor = Colors.blue;
                  statusIcon = Icons.hourglass_top_rounded;
                }
                if (isLate) {
                  statusColor = Colors.red;
                  statusIcon = Icons.error;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            statusIcon,
                            color: statusColor,
                            size: 30,
                          ),
                          title: Text(
                            'Tontine : ${payment['tontine']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Statut : $status',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                          trailing: Text(
                            payment['montant']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                        if (payment['transaction'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8.0,
                              left: 4.0,
                            ),
                            child: Text(
                              'Ref Réf : ${payment['transaction']}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (!isPaid && !isPending)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showMobileMoneyGateway(context, payment);
                              },
                              icon: const Icon(Icons.phone_android),
                              label: const Text(
                                'Cotiser via Wave / Orange Money',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // PASSAGE DE PAIEMENT SIMULÉ SÉNÉGAL
  void _showMobileMoneyGateway(
    BuildContext context,
    Map<String, dynamic> payment,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choisir un moyen de paiement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _processSimulation(context, payment, 'Wave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DC5D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Payer avec Wave 🟦',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  _processSimulation(context, payment, 'Orange Money'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Payer avec Orange Money 🟧',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processSimulation(
    BuildContext context,
    Map<String, dynamic> payment,
    String provider,
  ) async {
    Navigator.pop(context); // Fermer le BottomSheet

    // 1. EXTRACTION SÉCURISÉE DU MONTANT NUMÉRIQUE EXACT DE LA COTISATION
    String montantText = payment['montant'] ?? '0';
    int montantExact =
        int.tryParse(montantText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (montantExact <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: Le montant de la cotisation est invalide.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. CONSTRUCTION DES LIENS OFFICIELS AVEC BLOCAGE DU MONTANT
    final Uri waveUri = Uri.parse(
      'wave://payment?amount=$montantExact&currency=XOF&merchant=NATT-UGB',
    );
    final Uri orangeMoneyUri = Uri.parse('tel:%23144*1*1*$montantExact%23');

    final Uri targetUri = provider == 'Wave' ? waveUri : orangeMoneyUri;

    // 3. ENCLENCHEMENT DE LA REDIRECTION SYSTÈME AVEC LA SOMME BLOQUÉE
    try {
      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Simulation $provider : Envoi sécurisé bloqué à $montantExact FCFA (Impossible de modifier la somme)',
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur de Deep Linking sécurisé: $e');
    }

    // 4. DÉCLENCHEMENT DE LA VALIDATION AUTOMATIQUE DIRECTE DE LA BONNE SOMME
    setState(() {
      int idx = payment['memberIndex'];

      globalMembersList[idx][payment['statusKey']] = 'À jour';

      final int randomCode = 100000 + DateTime.now().millisecond;
      globalMembersList[idx][payment['txKey']] =
          '${provider == 'Wave' ? 'WAVE' : 'OM'}-$randomCode-${montantExact}F';

      if (currentConnectedMember != null &&
          currentConnectedMember!['nom'] == globalMembersList[idx]['nom']) {
        currentConnectedMember![payment['statusKey']] = 'À jour';
        currentConnectedMember![payment['txKey']] =
            globalMembersList[idx][payment['txKey']];
      }
    });

    // 5. SAUVEGARDE ET PERSISTANCE
    await saveMembersToLocal();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cotisation de $montantText validée et enregistrée avec succès ! 🎉',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  int indexWhereUnique() => DateTime.now().millisecond;
}

// ==========================================
// 5C. INTERFACE : PROFIL DE L'ESPACE MEMBRE
// ==========================================

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  bool _faceIdEnabled = false;

  // Contrôleurs pour le changement de mot de passe
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // 🛠️ METHODE DE SIMULATION VÉRIFICATION D'IDENTITÉ RESTAURÉE
  // Instance du système biométrique de l'appareil
  final LocalAuthentication _auth = LocalAuthentication();

  // Instance pour le contrôle de l'appareil photo
  final ImagePicker _picker = ImagePicker();

  // 🛠️ VRAIE FONCTION BIOMÉTRIE (FACE ID / EMPREINTE DIGITALE)
  // 🛠️ VRAIE FONCTION BIOMÉTRIE (CORRIGÉE SANS ERREURS)
  Future<void> _authenticateBiometrics(bool enable) async {
    if (!enable) {
      setState(() {
        _faceIdEnabled = false;
      });
      return;
    }

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() => _faceIdEnabled = false);
        if (!mounted) return; // Sécurité BuildContext
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre appareil ne supporte pas la biométrie (Simulateur).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Déclenchement standard compatible toutes versions
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Veuillez scanner votre empreinte ou visage pour activer Face ID',
      );

      setState(() {
        _faceIdEnabled = didAuthenticate;
      });

      if (didAuthenticate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔒 Authentification biométrique configurée avec succès !',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _faceIdEnabled = false);
      if (!mounted) return; // Sécurité BuildContext
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur biométrique : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 🛠️ VRAIE FONCTION APPAREIL PHOTO : ACTIVER LA CAMÉRA POUR LA CNI
  Future<void> _captureIdentityDocument() async {
    try {
      // Ouvre directement l'appareil photo natif du téléphone
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality:
            85, // Optimisation du poids pour la persistance réseau future
      );

      if (photo != null && mounted) {
        // Succès : La photo est prise ! Affichage d'une alerte de validation
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Document capturé'),
              ],
            ),
            content: const Text(
              'La photo de votre pièce d\'identité a été enregistrée avec succès. Elle sera transmise à l\'administrateur pour validation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Parfait'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir la caméra : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 🛠️ FONCTION 1 : MODIFIER LE MOT DE PASSE EN LOCAL
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier mon mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Ancien code secret',
              ),
            ),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau code secret',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _oldPasswordController.clear();
              _newPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C5C),
            ),
            onPressed: () async {
              String oldPass = _oldPasswordController.text.trim();
              String newPass = _newPasswordController.text.trim();

              // Extraction et nettoyage rigoureux du mot de passe en mémoire
              String currentPass = (currentConnectedMember?['password'] ?? '')
                  .toString()
                  .trim();

              if (oldPass.isEmpty || newPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez remplir tous les champs.'),
                  ),
                );
                return;
              }

              // --- CORRECTION CRITIQUE ---
              // Si le mot de passe en mémoire est vide (compte de test initial),
              // ou si la saisie ne correspond pas, on applique la vérification textuelle.
              if (currentPass.isNotEmpty && oldPass != currentPass) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ancien code secret incorrect.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              // Recherche du membre par identifiant unique (téléphone)
              int idx = globalMembersList.indexWhere(
                (m) =>
                    m['telephone'].toString().trim().replaceAll(' ', '') ==
                    currentConnectedMember?['telephone']
                        .toString()
                        .trim()
                        .replaceAll(' ', ''),
              );

              if (idx != -1) {
                setState(() {
                  globalMembersList[idx]['password'] = newPass;
                  currentConnectedMember!['password'] =
                      newPass; // Synchronise la session active
                });

                await saveMembersToLocal(); // Fixe le nouveau mot de passe dans SharedPreferences

                if (!mounted) return;
                Navigator.pop(context);
                _oldPasswordController.clear();
                _newPasswordController.clear();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Code secret modifié avec succès ! 🔑',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erreur de synchronisation du compte.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🛠️ FONCTION 3 : ASSISTANCE WHATSAPP / TELEPHONE
  void _contactAssistance() async {
    // Utilisation du schéma 'tel:' avec un numéro de test standard
    final Uri phoneUri = Uri(scheme: 'tel', path: '770000000');

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      } else {
        // Alternative universelle au cas où canLaunchUrl renvoie false sur l'émulateur
        await launchUrl(phoneUri);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ouverture du composeur téléphonique... 📞'),
          backgroundColor: Color(0xFF0F4C5C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nomMembre = currentConnectedMember?['nom'] ?? 'Membre Natt';
    final String telephoneMembre =
        currentConnectedMember?['telephone'] ?? '7XXXXXXXX';

    String initiales = "AM";
    List<String> mots = nomMembre.trim().split(' ');
    if (mots.length >= 2) {
      initiales = (mots[0].substring(0, 1) + mots[1].substring(0, 1))
          .toUpperCase();
    } else if (mots.isNotEmpty && mots[0].length >= 2) {
      initiales = mots[0].substring(0, 2).toUpperCase();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARTE BLANCHE EN-TÊTE UTILISATEUR
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFF2F4F7),
                      child: Text(
                        initiales,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F4C5C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomMembre,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            telephoneMembre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF7F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'MEMBRE DEPUIS SEPT. 2026',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F4C5C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'SÉCURITÉ & COMPTE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // 🔘 BOUTON 1 : BIOMÉTRIE / FACE ID
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF7F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF0F4C5C),
                  ),
                ),
                title: const Text(
                  'Activer Face ID',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A45),
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Utiliser la biométrie',
                  style: TextStyle(color: Colors.grey),
                ),
                trailing: Switch(
                  value: _faceIdEnabled,
                  activeThumbColor: const Color(0xFFFF7A45),
                  onChanged: (val) {
                    _authenticateBiometrics(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🔘 BOUTON 2 : MODIFIER LE MOT DE PASSE
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFFF7A45),
                  ),
                ),
                title: const Text(
                  'Modifier mon mot de passe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A45),
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Changer le mot de passe du compte',
                  style: TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 12),

            // ==========================================
            // 🔘 BOUTON 3 : VÉRIFICATION D'IDENTITÉ
            // ==========================================
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_ind_outlined,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    title: const Text(
                      'Vérification d\'identité',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7A45),
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: _captureIdentityDocument,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      bottom: 16.0,
                      right: 16.0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFEB2B2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Recto et verso à fournir',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'AIDE & ACCOMPAGNEMENT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // ==========================================
            // 🔘 BOUTON 4 : DÉCONNEXION DE SESSION
            // ==========================================
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  currentConnectedMember = null;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // ==========================================
            // 🔘 BOUTON 5 : ASSISTANCE TÉLÉPHONIQUE
            // ==========================================
            Center(
              child: TextButton(
                onPressed: _contactAssistance,
                child: const Text(
                  "Besoin d'aide ? Assistance",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A45),
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Center(
              child: Text(
                'VERSION 2.1.8',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black26,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// 🛠️ BOÎTE DE DIALOGUE GLOBALE POUR SÉLECTIONNER LE MEMBRE ET APPLIQUER LE PAIEMENT
void _showGlobalSocialPaymentDialog(BuildContext context) {
  if (globalMembersList.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucun membre enregistré dans l\'application.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  Map<String, dynamic>? _selectedMember;
  String? _selectedTontine;
  final TextEditingController _amountController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        List<dynamic> memberTontines = _selectedMember?['tontines'] ?? [];

        return AlertDialog(
          title: const Text('Enregistrer un versement social'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sélectionner le membre :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                hint: const Text('Choisir un membre'),
                value: _selectedMember,
                items: globalMembersList.map((member) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: member,
                    child: Text('${member['nom']} (${member['telephone']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    _selectedMember = value;
                    _selectedTontine =
                        null; // Réinitialise la tontine si le membre change
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Sélectionner la tontine :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Choisir une tontine'),
                value: _selectedTontine,
                items: memberTontines.map<DropdownMenuItem<String>>((tontine) {
                  return DropdownMenuItem<String>(
                    value: tontine.toString(),
                    child: Text(tontine.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    _selectedTontine = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Montant libre (FCFA) :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ex: 2000',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C5C),
              ),
              onPressed: () async {
                String amtStr = _amountController.text.trim();
                if (_selectedMember == null ||
                    _selectedTontine == null ||
                    amtStr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez remplir tous les champs.'),
                    ),
                  );
                  return;
                }

                int montant = int.tryParse(amtStr) ?? 0;
                if (montant <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Montant invalide.')),
                  );
                  return;
                }

                // Trouver l'index réel du membre sélectionné pour modifier ses données
                int memberIdx = globalMembersList.indexWhere(
                  (m) => m['telephone'] == _selectedMember!['telephone'],
                );
                if (memberIdx != -1) {
                  if (globalMembersList[memberIdx]['historique_social'] ==
                      null) {
                    globalMembersList[memberIdx]['historique_social'] = [];
                  }

                  // 1. Sauvegarde dans l'historique du membre
                  globalMembersList[memberIdx]['historique_social'].add({
                    'tontine': _selectedTontine,
                    'montant': montant,
                    'date': '19-10-2026',
                  });

                  // 2. Incrémentation de la caisse collective de la tontine
                  int tontineIdx = globalTontinesList.indexWhere(
                    (t) => t['nom'] == _selectedTontine,
                  );
                  if (tontineIdx != -1) {
                    int ancienTotal =
                        int.tryParse(
                          globalTontinesList[tontineIdx]['social_caisse_total']
                              .toString(),
                        ) ??
                        0;
                    globalTontinesList[tontineIdx]['social_caisse_total'] =
                        (ancienTotal + montant).toString();
                  }

                  // 3. Sauvegarde SharedPreferences locale
                  await saveMembersToLocal();
                  await saveTontinesToLocal();

                  _amountController.clear();
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Caisse Sociale alimentée de $montant FCFA pour ${_selectedMember!['nom']} ! 🎉',
                      ),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
              child: const Text(
                'Valider',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ),
  );
}
