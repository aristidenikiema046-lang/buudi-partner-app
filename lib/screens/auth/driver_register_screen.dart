import 'dart:convert'; // Import requis pour décoder la réponse JSON de Laravel
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:buudi_shared/buudi_shared.dart'; // FcmService + ApiConfig partagés

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({Key? key}) : super(key: key);

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<String> _steps = ["Informations", "Vérification", "Véhicule", "Confirmation"];

  // --- Clés de validation des formulaires ---
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  // --- Étape 1 : Contrôleurs et visibilité ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  File? _profileImage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // --- Étape 2 : Documents (Fichiers réels) ---
  File? _cniFile;
  File? _licenseFile;
  File? _selfieFile;
  File? _criminalRecordFile;

  // --- Étape 3 : Véhicule ---
  String _selectedVehicleType = "Voiture";
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();

  File? _vehicleImage;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    _promoController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, Function(File) onFileSelected) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Compresse pour soulager la base de données et l'envoi
      );
      if (pickedFile != null) {
        setState(() {
          onFileSelected(File(pickedFile.path));
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la sélection de l'image : $e");
    }
  }

  void _showImageSourceDialog(Function(File) onFileSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF5722)),
              title: const Text("Choisir depuis la galerie"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, onFileSelected);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF5722)),
              title: const Text("Prendre une photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, onFileSelected);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- TRAITEMENT DES ÉTAPES ---
  void _handleNextStep() {
    if (_currentStep == 0) {
      if (_profileImage == null) {
        _showSnackBar("Veuillez ajouter votre photo de profil.");
        return;
      }
      if (_formKeyStep1.currentState!.validate()) {
        _nextStep();
      }
    } else if (_currentStep == 1) {
      if (_cniFile == null) {
        _showSnackBar("La carte d'identité (CNI) est obligatoire.");
        return;
      }
      if (_licenseFile == null) {
        _showSnackBar("Le permis de conduire est obligatoire.");
        return;
      }
      if (_selfieFile == null) {
        _showSnackBar("Le selfie de contrôle est obligatoire.");
        return;
      }
      _nextStep();
    } else if (_currentStep == 2) {
      if (_vehicleImage == null) {
        _showSnackBar("Veuillez ajouter une photo du véhicule.");
        return;
      }
      if (_formKeyStep3.currentState!.validate()) {
        _submitRegistrationToBackend(); // Soumission réelle vers Laravel
      }
    }
  }

  // --- SOUMISSION RÉELLE MULTIPART AU SERVEUR ---
  Future<void> _submitRegistrationToBackend() async {
    setState(() => _isLoading = true);

    try {
      // 👈 2. Récupération dynamique du jeton FCM
      String? fcmToken = await FcmService.getToken();

      var uri = Uri.parse("${ApiConfig.baseUrlV1}/driver/register");
      var request = http.MultipartRequest("POST", uri);

      // --- En-têtes pour forcer la réponse JSON de Laravel ---
      request.headers['Accept'] = 'application/json';

      // --- Champs Textes ---
      request.fields['name'] = _nameController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['password'] = _passwordController.text.trim();
      request.fields['password_confirmation'] = _confirmPasswordController.text.trim();
      request.fields['city'] = _cityController.text.trim();
      request.fields['promo_code'] = _promoController.text.trim();
      request.fields['vehicle_type'] = _selectedVehicleType;
      request.fields['vehicle_brand'] = _brandController.text.trim();
      request.fields['vehicle_model'] = _modelController.text.trim();
      request.fields['vehicle_year'] = _yearController.text.trim();
      request.fields['vehicle_color'] = _colorController.text.trim();
      request.fields['vehicle_plate'] = _plateController.text.trim();
      request.fields['vehicle_seats'] = _seatsController.text.trim();
      
      // 👈 3. Transmission du token Firebase à Laravel
      request.fields['fcm_token'] = fcmToken ?? '';

      // --- Envoi des Fichiers Physiques ---
      request.files.add(await http.MultipartFile.fromPath('profile_image', _profileImage!.path));
      request.files.add(await http.MultipartFile.fromPath('cni', _cniFile!.path));
      request.files.add(await http.MultipartFile.fromPath('license', _licenseFile!.path));
      request.files.add(await http.MultipartFile.fromPath('selfie', _selfieFile!.path));
      request.files.add(await http.MultipartFile.fromPath('vehicle_image', _vehicleImage!.path));

      if (_criminalRecordFile != null) {
        request.files.add(await http.MultipartFile.fromPath('criminal_record', _criminalRecordFile!.path));
      }

      // --- Envoyer la requête ---
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      print("--------------------------------------------------");
      print("STATUS BACKEND : ${responseData.statusCode}");
      print("RETOUR LARAVEL : ${responseData.body}");
      print("--------------------------------------------------");

      setState(() => _isLoading = false);

      if (responseData.statusCode == 201 || responseData.statusCode == 200) {
        _nextStep(); // Succès
      } 
      // Gestion de l'erreur de validation Laravel 422
      else if (responseData.statusCode == 422) {
        try {
          final Map<String, dynamic> errorsMap = json.decode(responseData.body);

          if (errorsMap.containsKey('errors')) {
            Map<String, dynamic> validationErrors = errorsMap['errors'];
            String firstErrorMsg = validationErrors.values.first[0];
            _showSnackBar(firstErrorMsg);
          } else if (errorsMap.containsKey('message')) {
            _showSnackBar(errorsMap['message']);
          } else {
            _showSnackBar("Erreur de validation des champs du formulaire.");
          }
        } catch (_) {
          _showSnackBar("Certaines informations saisies sont invalides.");
        }
      } else {
        _showSnackBar("Échec de l'envoi de vos informations. (Code: ${responseData.statusCode})");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Erreur de connexion. Vérifiez votre réseau internet.");
      debugPrint("Erreur d'enregistrement : $e");
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: _previousStep,
        ),
        title: const Text(
          "Inscription - Chauffeur Pro",
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildStepper(),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Infos(),
                  _buildStep2Docs(),
                  _buildStep3Vehicule(),
                  _buildStep4Confirmation(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length, (index) {
              bool isCompleted = index < _currentStep;
              bool isActive = index == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isActive || isCompleted ? const Color(0xFFFF5722) : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (index < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted ? const Color(0xFFFF5722) : Colors.grey[200],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_steps.length, (index) {
              bool isActive = index == _currentStep;
              return Expanded(
                child: Text(
                  _steps[index],
                  textAlign: index == 0
                      ? TextAlign.left
                      : index == _steps.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? const Color(0xFFFF5722) : Colors.grey[400],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Infos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? const Icon(Icons.person_rounded, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showImageSourceDialog((file) {
                        setState(() {
                          _profileImage = file;
                        });
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFFF5722), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text("Ajouter une photo de profil *", style: TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 20),
            const Text("Informations personnelles", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTextField(
              "Nom complet",
              "Koffi Jean",
              Icons.person_outline_rounded,
              _nameController,
              validator: (v) => v!.isEmpty ? "Veuillez entrer votre nom complet" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Numéro de téléphone",
              "+225 07 12 34 56 78",
              Icons.phone_android_rounded,
              _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v!.isEmpty) return "Le numéro de téléphone est requis";
                if (v.length < 8) return "Veuillez entrer un numéro valide";
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Email",
              "jeankoffi@gmail.com",
              Icons.mail_outline_rounded,
              _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.isEmpty) return "L'adresse email est requise";
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return "Veuillez entrer un email valide";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Mot de passe",
              "••••••••",
              Icons.lock_outline_rounded,
              _passwordController,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) => v!.length < 6 ? "Le mot de passe doit contenir au moins 6 caractères" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Confirmer le mot de passe",
              "••••••••",
              Icons.lock_outline_rounded,
              _confirmPasswordController,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: (v) {
                if (v!.isEmpty) return "Veuillez confirmer votre mot de passe";
                if (v != _passwordController.text) return "Les mots de passe ne correspondent pas";
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text("Informations complémentaires", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTextField(
              "Ville d'activité",
              "Abidjan, Côte d'Ivoire",
              Icons.location_on_outlined,
              _cityController,
              validator: (v) => v!.isEmpty ? "Veuillez indiquer votre ville d'activité" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Code de parrainage (optionnel)",
              "Entrez un code",
              Icons.card_giftcard_rounded,
              _promoController,
            ),
            const SizedBox(height: 30),
            _buildButton("Continuer", _handleNextStep),
            const SizedBox(height: 15),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text("Vos données sont hautement sécurisées", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Docs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text("Vérification de votre identité", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Téléversez vos documents (Format JPG/PNG requis)", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 20),
          _buildDocUploadCard(
            "Carte nationale d'identité *",
            "Recto / Verso",
            _cniFile,
            (file) => setState(() => _cniFile = file),
          ),
          const SizedBox(height: 12),
          _buildDocUploadCard(
            "Permis de conduire *",
            "Recto / Verso",
            _licenseFile,
            (file) => setState(() => _licenseFile = file),
          ),
          const SizedBox(height: 12),
          _buildDocUploadCard(
            "Selfie (visage dégagé) *",
            "Prenez un selfie clair",
            _selfieFile,
            (file) => setState(() => _selfieFile = file),
          ),
          const SizedBox(height: 12),
          _buildDocUploadCard(
            "Casier judiciaire",
            "Moins de 3 mois (optionnel)",
            _criminalRecordFile,
            (file) => setState(() => _criminalRecordFile = file),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF6F0), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFFFF5722), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Vos documents sont chiffrés de bout en bout et réservés uniquement à la validation réglementaire de votre dossier.",
                    style: TextStyle(fontSize: 11, color: Colors.orange[900], height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildButton("Continuer", _handleNextStep),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStep3Vehicule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKeyStep3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Informations sur le véhicule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () => _showImageSourceDialog((file) {
                  setState(() {
                    _vehicleImage = file;
                  });
                }),
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _vehicleImage != null ? Colors.green.shade200 : Colors.transparent),
                    image: _vehicleImage != null
                        ? DecorationImage(image: FileImage(_vehicleImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _vehicleImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 6),
                            const Text("Ajouter une photo du véhicule *", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      : Container(
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.all(8),
                          child: const CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 14,
                            child: Icon(Icons.check, size: 16, color: Colors.white),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Type de véhicule", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVehicleType,
                  isExpanded: true,
                  onChanged: (value) => setState(() => _selectedVehicleType = value!),
                  items: ["Voiture", "Moto", "Vélo"].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Marque",
              "Toyota",
              Icons.branding_watermark_outlined,
              _brandController,
              validator: (v) => v!.isEmpty ? "Veuillez entrer la marque" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Modèle",
              "Corolla",
              Icons.model_training_rounded,
              _modelController,
              validator: (v) => v!.isEmpty ? "Veuillez entrer le modèle" : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    "Année",
                    "2020",
                    Icons.calendar_today_rounded,
                    _yearController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return "Requis";
                      final val = int.tryParse(v);
                      if (val == null || val < 1990 || val > DateTime.now().year + 1) return "Invalide";
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    "Couleur",
                    "Gris",
                    Icons.color_lens_outlined,
                    _colorController,
                    validator: (v) => v!.isEmpty ? "Requis" : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Immatriculation",
              "1234AB01",
              Icons.subtitles_rounded,
              _plateController,
              validator: (v) => v!.isEmpty ? "Veuillez renseigner la plaque" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Nombre de places",
              "5",
              Icons.airline_seat_recline_normal_rounded,
              _seatsController,
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? "Requis" : null,
            ),
            const SizedBox(height: 30),
            _buildButton("Soumettre mon dossier", _handleNextStep, loading: _isLoading),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Confirmation() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          const CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFFFFF3E0),
            child: Icon(Icons.schedule_rounded, size: 40, color: Color(0xFFFF9800)),
          ),
          const SizedBox(height: 20),
          const Text("Dossier en cours d'examen !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Vos informations et documents d'identité ont été transmis avec succès aux gérants de la plateforme.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildRecapRow("Nom complet", _nameController.text),
                const Divider(),
                _buildRecapRow("Téléphone", _phoneController.text),
                const Divider(),
                _buildRecapRow("Statut du dossier", "En attente de validation"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFFFF9800), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Les gérants étudient actuellement vos pièces justificatives. Vous recevrez un SMS et une notification d'activation dès validation sous 24h.",
                    style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildButton("Fermer l'application", () {
            Navigator.popUntil(context, (route) => route.isFirst);
          }),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  // --- COMPOSANTS REUTILISABLES ---

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey[400],
                      size: 18,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F9),
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDocUploadCard(String title, String subtitle, File? file, Function(File) onSelected) {
    return InkWell(
      onTap: () => _showImageSourceDialog(onSelected),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? Colors.green.shade200 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: file != null ? Colors.green.shade50 : const Color(0xFFFFF6F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                file != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                color: file != null ? Colors.green : const Color(0xFFFF5722),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    file != null ? "Document sélectionné" : subtitle,
                    style: TextStyle(color: file != null ? Colors.green : Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed, {bool loading = false}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5722),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRecapRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}