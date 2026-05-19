import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // ── Font scale ───────────────────────────────────────────────────────────
  double _fontScale = 1.0; // 0.7 → 1.5
  double get fontScale => _fontScale;
  set fontScale(double v) {
    _fontScale = v.clamp(0.7, 1.5);
    _save();
    notifyListeners();
  }

  // ── Dark mode ────────────────────────────────────────────────────────────
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  set isDarkMode(bool v) {
    _isDarkMode = v;
    _save();
    notifyListeners();
  }

  // ── Language ─────────────────────────────────────────────────────────────
  String _language = 'English';
  String get language => _language;
  set language(String v) {
    _language = v;
    _save();
    notifyListeners();
  }

  bool get isRtl => _language == 'العربية';

  // ── Supported languages ──────────────────────────────────────────────────
  static const List<String> supportedLanguages = [
    'English',
    'العربية',
    'Français',
    'Español',
    'Deutsch',
  ];

  // ── Translations ─────────────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _translations = {
    'English': {
      // Nav
      'nav_home': 'Home',
      'nav_my_heart': 'My Heart',
      'nav_contacts': 'Contacts',
      'nav_scheduled': 'Scheduled',
      'nav_profile': 'Profile',
      // Home
      'hi': 'Hi',
      'vital_signs': 'Vital Signs',
      'blood_pressure': 'Blood Pressure',
      'heart_rate': 'Heart Rate',
      'oxygen_level': 'Oxygen Level',
      'normal': 'Normal',
      'normal_range': 'Normal range',
      'excellent': 'Excellent',
      'sys': 'SYS',
      'dia': 'DIA',
      'spo2_label': 'SpO₂',
      // Contacts
      'contacts': 'Contacts',
      'saved': 'saved',
      'no_contacts': 'No contacts added',
      'tap_add_contacts': 'Tap the + button to add contacts',
      'add_contact': 'Add Contact',
      'edit_contact': 'Edit Contact',
      'relationship': 'Relationship',
      'relative': 'Relative',
      'doctor': 'Doctor',
      'other': 'Other',
      'name': 'Name',
      'phone_number': 'Phone Number',
      'email_address': 'Email Address',
      'save_contact': 'Save Contact',
      'update_contact': 'Update Contact',
      'contact_added': 'Contact added successfully',
      'contact_updated': 'Contact updated successfully',
      'contact_deleted': 'Contact deleted',
      'failed_load_contacts': 'Failed to load contacts',
      'failed_add_contact': 'Failed to add contact',
      'failed_update_contact': 'Failed to update contact',
      'failed_delete_contact': 'Failed to delete contact',
      'cannot_edit_missing_id': 'Cannot edit contact: missing ID',
      'cannot_delete_missing_id': 'Cannot delete contact: missing ID',
      'enter_phone_or_email': 'Please enter phone or email',
      // Profile
      'my_profile': 'My Profile',
      'profile_name': 'Name',
      'profile_email': 'Email',
      'profile_age': 'Age',
      'profile_phone': 'Phone',
      'profile_age_not_set': 'Not set',
      'profile_age_years': 'years',
      'health_score': 'Health Score',
      'my_doctor': 'My Doctor',
      'change': 'Change',
      'no_doctor_assigned': 'No doctor assigned',
      'tap_select_doctor': 'Tap to select your doctor',
      'doctor_assigned': 'Doctor assigned successfully',
      // Settings
      'settings': 'Settings',
      'font_size': 'Font Size',
      'preview_scale': 'Preview — scale',
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'easy_on_eyes': 'Easy on the eyes',
      'bright_clean': 'Bright & clean',
      'contact_us': 'Contact Us',
      'get_in_touch': 'Get in Touch',
      'here_to_help': "We're here to help",
      'email': 'Email',
      'phone': 'Phone',
      'website': 'Website',
      'address': 'Address',
      'coming_soon': 'Coming soon...',
      'language': 'Language',
    },
    'العربية': {
      // Nav
      'nav_home': 'الرئيسية',
      'nav_my_heart': 'قلبي',
      'nav_contacts': 'جهات الاتصال',
      'nav_scheduled': 'المواعيد',
      'nav_profile': 'الملف الشخصي',
      // Home
      'hi': 'مرحباً',
      'vital_signs': 'العلامات الحيوية',
      'blood_pressure': 'ضغط الدم',
      'heart_rate': 'معدل ضربات القلب',
      'oxygen_level': 'مستوى الأكسجين',
      'normal': 'طبيعي',
      'normal_range': 'النطاق الطبيعي',
      'excellent': 'ممتاز',
      'sys': 'الانقباضي',
      'dia': 'الانبساطي',
      'spo2_label': 'SpO₂',
      // Contacts
      'contacts': 'جهات الاتصال',
      'saved': 'محفوظ',
      'no_contacts': 'لا توجد جهات اتصال',
      'tap_add_contacts': 'اضغط على + لإضافة جهة اتصال',
      'add_contact': 'إضافة جهة اتصال',
      'edit_contact': 'تعديل جهة الاتصال',
      'relationship': 'العلاقة',
      'relative': 'قريب',
      'doctor': 'طبيب',
      'other': 'أخرى',
      'name': 'الاسم',
      'phone_number': 'رقم الهاتف',
      'email_address': 'البريد الإلكتروني',
      'save_contact': 'حفظ جهة الاتصال',
      'update_contact': 'تحديث جهة الاتصال',
      'contact_added': 'تمت إضافة جهة الاتصال بنجاح',
      'contact_updated': 'تم تحديث جهة الاتصال بنجاح',
      'contact_deleted': 'تم حذف جهة الاتصال',
      'failed_load_contacts': 'فشل تحميل جهات الاتصال',
      'failed_add_contact': 'فشل إضافة جهة الاتصال',
      'failed_update_contact': 'فشل تحديث جهة الاتصال',
      'failed_delete_contact': 'فشل حذف جهة الاتصال',
      'cannot_edit_missing_id': 'لا يمكن التعديل: معرّف مفقود',
      'cannot_delete_missing_id': 'لا يمكن الحذف: معرّف مفقود',
      'enter_phone_or_email': 'يرجى إدخال الهاتف أو البريد الإلكتروني',
      // Profile
      'my_profile': 'ملفي الشخصي',
      'profile_name': 'الاسم',
      'profile_email': 'البريد الإلكتروني',
      'profile_age': 'العمر',
      'profile_phone': 'الهاتف',
      'profile_age_not_set': 'غير محدد',
      'profile_age_years': 'سنة',
      'health_score': 'نقاط الصحة',
      'my_doctor': 'طبيبي',
      'change': 'تغيير',
      'no_doctor_assigned': 'لم يتم تعيين طبيب',
      'tap_select_doctor': 'اضغط لاختيار طبيبك',
      'doctor_assigned': 'تم تعيين الطبيب بنجاح',
      // Settings
      'settings': 'الإعدادات',
      'font_size': 'حجم الخط',
      'preview_scale': 'معاينة — نسبة',
      'appearance': 'المظهر',
      'dark_mode': 'الوضع الداكن',
      'light_mode': 'الوضع الفاتح',
      'easy_on_eyes': 'مريح للعيون',
      'bright_clean': 'مشرق ونظيف',
      'contact_us': 'تواصل معنا',
      'get_in_touch': 'تواصل معنا',
      'here_to_help': 'نحن هنا للمساعدة',
      'email': 'البريد الإلكتروني',
      'phone': 'الهاتف',
      'website': 'الموقع الإلكتروني',
      'address': 'العنوان',
      'coming_soon': 'قريباً...',
      'language': 'اللغة',
    },
    'Français': {
      // Nav
      'nav_home': 'Accueil',
      'nav_my_heart': 'Mon Cœur',
      'nav_contacts': 'Contacts',
      'nav_scheduled': 'Planifié',
      'nav_profile': 'Profil',
      // Home
      'hi': 'Salut',
      'vital_signs': 'Signes Vitaux',
      'blood_pressure': 'Pression Artérielle',
      'heart_rate': 'Fréquence Cardiaque',
      'oxygen_level': "Niveau d'Oxygène",
      'normal': 'Normal',
      'normal_range': 'Plage normale',
      'excellent': 'Excellent',
      'sys': 'SYS',
      'dia': 'DIA',
      'spo2_label': 'SpO₂',
      // Contacts
      'contacts': 'Contacts',
      'saved': 'enregistré(s)',
      'no_contacts': 'Aucun contact ajouté',
      'tap_add_contacts': 'Appuyez sur + pour ajouter',
      'add_contact': 'Ajouter Contact',
      'edit_contact': 'Modifier Contact',
      'relationship': 'Relation',
      'relative': 'Proche',
      'doctor': 'Médecin',
      'other': 'Autre',
      'name': 'Nom',
      'phone_number': 'Téléphone',
      'email_address': 'Email',
      'save_contact': 'Enregistrer',
      'update_contact': 'Mettre à jour',
      'contact_added': 'Contact ajouté avec succès',
      'contact_updated': 'Contact mis à jour avec succès',
      'contact_deleted': 'Contact supprimé',
      'failed_load_contacts': 'Échec du chargement',
      'failed_add_contact': "Échec de l'ajout",
      'failed_update_contact': 'Échec de la mise à jour',
      'failed_delete_contact': 'Échec de la suppression',
      'cannot_edit_missing_id': 'Impossible de modifier: ID manquant',
      'cannot_delete_missing_id': 'Impossible de supprimer: ID manquant',
      'enter_phone_or_email': 'Entrez téléphone ou email',
      // Profile
      'my_profile': 'Mon Profil',
      'profile_name': 'Nom',
      'profile_email': 'Email',
      'profile_age': 'Âge',
      'profile_phone': 'Téléphone',
      'profile_age_not_set': 'Non défini',
      'profile_age_years': 'ans',
      'health_score': 'Score de Santé',
      'my_doctor': 'Mon Médecin',
      'change': 'Changer',
      'no_doctor_assigned': 'Aucun médecin assigné',
      'tap_select_doctor': 'Appuyez pour choisir',
      'doctor_assigned': 'Médecin assigné avec succès',
      // Settings
      'settings': 'Paramètres',
      'font_size': 'Taille de Police',
      'preview_scale': 'Aperçu — échelle',
      'appearance': 'Apparence',
      'dark_mode': 'Mode Sombre',
      'light_mode': 'Mode Clair',
      'easy_on_eyes': 'Doux pour les yeux',
      'bright_clean': 'Lumineux & propre',
      'contact_us': 'Contactez-nous',
      'get_in_touch': 'Nous Contacter',
      'here_to_help': 'Nous sommes là pour vous',
      'email': 'Email',
      'phone': 'Téléphone',
      'website': 'Site Web',
      'address': 'Adresse',
      'coming_soon': 'Bientôt...',
      'language': 'Langue',
    },
    'Español': {
      // Nav
      'nav_home': 'Inicio',
      'nav_my_heart': 'Mi Corazón',
      'nav_contacts': 'Contactos',
      'nav_scheduled': 'Programado',
      'nav_profile': 'Perfil',
      // Home
      'hi': 'Hola',
      'vital_signs': 'Signos Vitales',
      'blood_pressure': 'Presión Arterial',
      'heart_rate': 'Frecuencia Cardíaca',
      'oxygen_level': 'Nivel de Oxígeno',
      'normal': 'Normal',
      'normal_range': 'Rango normal',
      'excellent': 'Excelente',
      'sys': 'SIS',
      'dia': 'DIA',
      'spo2_label': 'SpO₂',
      // Contacts
      'contacts': 'Contactos',
      'saved': 'guardado(s)',
      'no_contacts': 'No hay contactos',
      'tap_add_contacts': 'Toca + para añadir contactos',
      'add_contact': 'Añadir Contacto',
      'edit_contact': 'Editar Contacto',
      'relationship': 'Relación',
      'relative': 'Familiar',
      'doctor': 'Médico',
      'other': 'Otro',
      'name': 'Nombre',
      'phone_number': 'Teléfono',
      'email_address': 'Correo Electrónico',
      'save_contact': 'Guardar',
      'update_contact': 'Actualizar',
      'contact_added': 'Contacto añadido con éxito',
      'contact_updated': 'Contacto actualizado',
      'contact_deleted': 'Contacto eliminado',
      'failed_load_contacts': 'Error al cargar',
      'failed_add_contact': 'Error al añadir',
      'failed_update_contact': 'Error al actualizar',
      'failed_delete_contact': 'Error al eliminar',
      'cannot_edit_missing_id': 'No se puede editar: ID faltante',
      'cannot_delete_missing_id': 'No se puede eliminar: ID faltante',
      'enter_phone_or_email': 'Ingrese teléfono o correo',
      // Profile
      'my_profile': 'Mi Perfil',
      'profile_name': 'Nombre',
      'profile_email': 'Correo',
      'profile_age': 'Edad',
      'profile_phone': 'Teléfono',
      'profile_age_not_set': 'No establecido',
      'profile_age_years': 'años',
      'health_score': 'Puntuación de Salud',
      'my_doctor': 'Mi Médico',
      'change': 'Cambiar',
      'no_doctor_assigned': 'Sin médico asignado',
      'tap_select_doctor': 'Toca para seleccionar',
      'doctor_assigned': 'Médico asignado con éxito',
      // Settings
      'settings': 'Ajustes',
      'font_size': 'Tamaño de Fuente',
      'preview_scale': 'Vista previa — escala',
      'appearance': 'Apariencia',
      'dark_mode': 'Modo Oscuro',
      'light_mode': 'Modo Claro',
      'easy_on_eyes': 'Suave para los ojos',
      'bright_clean': 'Brillante y limpio',
      'contact_us': 'Contáctenos',
      'get_in_touch': 'Ponerse en Contacto',
      'here_to_help': 'Estamos aquí para ayudar',
      'email': 'Correo',
      'phone': 'Teléfono',
      'website': 'Sitio Web',
      'address': 'Dirección',
      'coming_soon': 'Próximamente...',
      'language': 'Idioma',
    },
    'Deutsch': {
      // Nav
      'nav_home': 'Startseite',
      'nav_my_heart': 'Mein Herz',
      'nav_contacts': 'Kontakte',
      'nav_scheduled': 'Geplant',
      'nav_profile': 'Profil',
      // Home
      'hi': 'Hallo',
      'vital_signs': 'Vitalzeichen',
      'blood_pressure': 'Blutdruck',
      'heart_rate': 'Herzfrequenz',
      'oxygen_level': 'Sauerstoffsättigung',
      'normal': 'Normal',
      'normal_range': 'Normaler Bereich',
      'excellent': 'Ausgezeichnet',
      'sys': 'SYS',
      'dia': 'DIA',
      'spo2_label': 'SpO₂',
      // Contacts
      'contacts': 'Kontakte',
      'saved': 'gespeichert',
      'no_contacts': 'Keine Kontakte',
      'tap_add_contacts': 'Tippen Sie auf +',
      'add_contact': 'Kontakt hinzufügen',
      'edit_contact': 'Kontakt bearbeiten',
      'relationship': 'Beziehung',
      'relative': 'Verwandter',
      'doctor': 'Arzt',
      'other': 'Sonstiges',
      'name': 'Name',
      'phone_number': 'Telefonnummer',
      'email_address': 'E-Mail-Adresse',
      'save_contact': 'Speichern',
      'update_contact': 'Aktualisieren',
      'contact_added': 'Kontakt erfolgreich hinzugefügt',
      'contact_updated': 'Kontakt aktualisiert',
      'contact_deleted': 'Kontakt gelöscht',
      'failed_load_contacts': 'Fehler beim Laden',
      'failed_add_contact': 'Fehler beim Hinzufügen',
      'failed_update_contact': 'Fehler beim Aktualisieren',
      'failed_delete_contact': 'Fehler beim Löschen',
      'cannot_edit_missing_id': 'Bearbeiten nicht möglich: ID fehlt',
      'cannot_delete_missing_id': 'Löschen nicht möglich: ID fehlt',
      'enter_phone_or_email': 'Telefon oder E-Mail eingeben',
      // Profile
      'my_profile': 'Mein Profil',
      'profile_name': 'Name',
      'profile_email': 'E-Mail',
      'profile_age': 'Alter',
      'profile_phone': 'Telefon',
      'profile_age_not_set': 'Nicht festgelegt',
      'profile_age_years': 'Jahre',
      'health_score': 'Gesundheitspunktzahl',
      'my_doctor': 'Mein Arzt',
      'change': 'Ändern',
      'no_doctor_assigned': 'Kein Arzt zugewiesen',
      'tap_select_doctor': 'Tippen um zu wählen',
      'doctor_assigned': 'Arzt erfolgreich zugewiesen',
      // Settings
      'settings': 'Einstellungen',
      'font_size': 'Schriftgröße',
      'preview_scale': 'Vorschau — Skalierung',
      'appearance': 'Erscheinungsbild',
      'dark_mode': 'Dunkler Modus',
      'light_mode': 'Heller Modus',
      'easy_on_eyes': 'Augenfreundlich',
      'bright_clean': 'Hell & sauber',
      'contact_us': 'Kontaktieren Sie uns',
      'get_in_touch': 'In Kontakt treten',
      'here_to_help': 'Wir helfen gerne',
      'email': 'E-Mail',
      'phone': 'Telefon',
      'website': 'Webseite',
      'address': 'Adresse',
      'coming_soon': 'Demnächst...',
      'language': 'Sprache',
    },
  };

  /// Looks up a translation for the given key in the current language.
  /// Falls back to English if the key is missing.
  String t(String key) {
    final langMap = _translations[_language];
    if (langMap != null && langMap.containsKey(key)) {
      return langMap[key]!;
    }
    // Fallback to English
    return _translations['English']?[key] ?? key;
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontScale = (prefs.getDouble('fontScale') ?? 1.0).clamp(0.7, 1.5);
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _language = prefs.getString('language') ?? 'English';
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontScale', _fontScale);
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setString('language', _language);
  }

  // ── Theme data ───────────────────────────────────────────────────────────
  ThemeData get themeData {
    if (_isDarkMode) {
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1923),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF148EBB),
          surface: const Color(0xFF1A2A3A),
        ),
        cardColor: const Color(0xFF1A2A3A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1923),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
        ),
      );
    } else {
      return ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF148EBB),
          surface: Colors.white,
        ),
        cardColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[100],
          foregroundColor: const Color(0xFF1A2A3A),
        ),
      );
    }
  }
}
