import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:buudi_shared/buudi_shared.dart';

/// Inscription Livreur.
///
/// NOTE MIGRATION : le back-office n'a pas de table séparée pour les
/// livreurs : `driver_profiles` couvre déjà tous les `vehicle_type`
/// (voiture, moto, vélo). On réutilise donc le même endpoint
/// `POST /v1/driver/register` que pour les chauffeurs (mêmes clés de champs
/// et de fichiers), ce qui correspond à la demande "chauffeurs et livreurs
/// dans la même application" et évite de dupliquer un modèle côté Laravel.
class DeliveryRegisterScreen extends StatefulWidget {
  const DeliveryRegisterScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryRegisterScreen> createState() => _DeliveryRegisterScreenState();
}

class _DeliveryRegisterScreenState extends State<DeliveryRegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  final List<String> _steps = ["Informations", "Véhicule", "Documents", "Confirmation"];

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // --- Étape 1 : Informations personnelles ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  File? _profileImage;

  // --- Étape 2 : Véhicule ---
  String _selectedVehicle = "Moto";
  final TextEditingController _vehicleBrand = TextEditingController();
  final TextEditingController _vehicleModel = TextEditingController();
  final TextEditingController _vehicleYear = TextEditingController();
  final TextEditingController _vehicleColor = TextEditingController();
  final TextEditingController _vehiclePlate = TextEditingController();

  // --- Étape 3 : Documents ---
  final ImagePicker _picker = ImagePicker();
  File? _identityFile;
  File? _licenseFile;
  File? _selfieFile;
  File? _registrationFile; // Carte grise / immatriculation
  File? _insuranceFile; // Optionnel

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleBrand.dispose();
    _vehicleModel.dispose();
    _vehicleYear.dispose();
    _vehicleColor.dispose();
    _vehiclePlate.dispose();
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

  Future<void> _pickImage(ImageSource source, Function(File) onFileSelected) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() => onFileSelected(File(pickedFile.path)));
      }
    } catch (e) {
      debugPrint("Erreur lors de la sélection de l'image : $e");
    }
  }

  void _showImageSourceDialog(Function(File) onFileSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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

  void _handleNextStep() {
    if (_currentStep == 0) {
      if (_profileImage == null) {
        _showSnackBar("Veuillez ajouter votre photo de profil.");
        return;
      }
      if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
        _showSnackBar("Les mots de passe ne correspondent pas.");
        return;
      }
      if (_formKeyStep1.currentState!.validate()) {
        _nextStep();
      }
    } else if (_currentStep == 1) {
      if (_formKeyStep2.currentState!.validate()) {
        _nextStep();
      }
    } else if (_currentStep == 2) {
      if (_identityFile == null) {
        _showSnackBar("La pièce d'identité est obligatoire.");
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
      if (_registrationFile == null) {
        _showSnackBar("La carte grise / immatriculation est obligatoire.");
        return;
      }
      _submitRegistrationToBackend();
    }
  }

  Future<void> _submitRegistrationToBackend() async {
    setState(() => _isLoading = true);

    try {
      String? fcmToken = await FcmService.getToken();

      var uri = Uri.parse("${ApiConfig.baseUrlV1}/driver/register");
      var request = http.MultipartRequest("POST", uri);
      request.headers['Accept'] = 'application/json';

      request.fields['name'] = _nameController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['password'] = _passwordController.text.trim();
      request.fields['password_confirmation'] = _confirmPasswordController.text.trim();
      request.fields['city'] = _cityController.text.trim();
      request.fields['vehicle_type'] = _selectedVehicle;
      request.fields['vehicle_brand'] = _vehicleBrand.text.trim();
      request.fields['vehicle_model'] = _vehicleModel.text.trim();
      request.fields['vehicle_year'] = _vehicleYear.text.trim();
      request.fields['vehicle_color'] = _vehicleColor.text.trim();
      request.fields['vehicle_plate'] = _vehiclePlate.text.trim();
      // Le backend (partagé avec l'inscription chauffeur) exige vehicle_seats
      // même si ça n'a pas de sens pour une Moto/Vélo et n'apparaît pas sur
      // la maquette Livreur : on envoie une valeur par défaut plutôt que
      // d'afficher un champ qui n'a pas lieu d'être pour ce parcours.
      request.fields['vehicle_seats'] = '1';
      request.fields['fcm_token'] = fcmToken ?? '';

      // Le backend attend `cni` / `license` / `vehicle_image` — on réutilise
      // les mêmes clés pour rester compatible avec le contrôleur chauffeur
      // existant. `vehicle_image` (requis, doit être une image) reçoit ici
      // la photo de la carte grise faute de champ dédié côté back-office.
      request.files.add(await http.MultipartFile.fromPath('profile_image', _profileImage!.path));
      request.files.add(await http.MultipartFile.fromPath('cni', _identityFile!.path));
      request.files.add(await http.MultipartFile.fromPath('license', _licenseFile!.path));
      request.files.add(await http.MultipartFile.fromPath('selfie', _selfieFile!.path));
      request.files.add(await http.MultipartFile.fromPath('vehicle_image', _registrationFile!.path));
      if (_insuranceFile != null) {
        request.files.add(await http.MultipartFile.fromPath('criminal_record', _insuranceFile!.path));
      }

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      setState(() => _isLoading = false);

      if (responseData.statusCode == 201 || responseData.statusCode == 200) {
        _nextStep();
      } else if (responseData.statusCode == 422) {
        try {
          final Map<String, dynamic> errorsMap = json.decode(responseData.body);
          if (errorsMap.containsKey('errors')) {
            Map<String, dynamic> validationErrors = errorsMap['errors'];
            String firstErrorMsg = validationErrors.values.first[0];
            _showSnackBar(firstErrorMsg);
          } else {
            _showSnackBar(errorsMap['message'] ?? "Erreur de validation des champs du formulaire.");
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
      debugPrint("Erreur d'enregistrement livreur : $e");
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
          "Inscription - Livreur",
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
                  _buildStep2Vehicule(),
                  _buildStep3Docs(),
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
      child: Row(
        children: List.generate(_steps.length, (index) {
          bool isCompleted = index < _currentStep;
          bool isActive = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted ? const Color(0xFFFF5722) : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(isCompleted ? Icons.check : null, size: 14, color: Colors.white),
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(height: 2, color: isCompleted ? const Color(0xFFFF5722) : Colors.grey[200]),
                  ),
              ],
            ),
          );
        }),
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
                        ? const Icon(Icons.delivery_dining_rounded, size: 45, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showImageSourceDialog((file) {
                        setState(() => _profileImage = file);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFFF5722), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text("Ajoutez une photo *", style: TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 20),
            const Text("Informations personnelles", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField("Nom complet", "Kouassi Ibrahim", Icons.person_outline_rounded, _nameController,
                validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Numéro de téléphone", "+225 07 12 34 56 78", Icons.phone_android_rounded, _phoneController,
                keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Email", "ibrahim.kouassi@gmail.com", Icons.mail_outline_rounded, _emailController,
                keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Ville de résidence", "Abidjan, Côte d'Ivoire", Icons.location_on_outlined, _cityController,
                validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField(
              "Mot de passe",
              "••••••••",
              Icons.lock_outline_rounded,
              _passwordController,
              obscureText: _obscurePassword,
              isPassword: true,
              onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) => (v?.length ?? 0) < 6 ? "6 caractères minimum" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Confirmer le mot de passe",
              "••••••••",
              Icons.lock_outline_rounded,
              _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              isPassword: true,
              onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: (v) => v!.isEmpty ? "Requis" : null,
            ),
            const SizedBox(height: 40),
            _buildButton("Continuer", _handleNextStep),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Vehicule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Informations du véhicule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Ajoutez les informations de votre moyen de livraison.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            const Text("Type de moyen", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildVehicleSelector("Moto", Icons.two_wheeler_rounded),
                const SizedBox(width: 12),
                _buildVehicleSelector("Vélo", Icons.pedal_bike_rounded),
                const SizedBox(width: 12),
                _buildVehicleSelector("Voiture", Icons.directions_car_rounded),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField("Marque", "Yamaha", Icons.branding_watermark_outlined, _vehicleBrand,
                validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Modèle", "XMAX 300", Icons.model_training_rounded, _vehicleModel,
                validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Année", "2022", Icons.calendar_today_rounded, _vehicleYear,
                keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Couleur", "Noir", Icons.color_lens_outlined, _vehicleColor,
                validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 12),
            _buildTextField("Numéro d'immatriculation", "1234AB01", Icons.subtitles_rounded, _vehiclePlate,
                validator: (v) => v!.isEmpty ? "Requis" : null),
            const SizedBox(height: 30),
            _buildButton("Continuer", _handleNextStep),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Docs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Documents requis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Téléversez des photos claires et valides.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          _buildDocUploadCard("Pièce d'identité", "CNI, passeport...", _identityFile, (f) => _identityFile = f),
          const SizedBox(height: 12),
          _buildDocUploadCard("Permis de conduire", "Recto/verso", _licenseFile, (f) => _licenseFile = f),
          const SizedBox(height: 12),
          _buildDocUploadCard("Selfie (visage dégagé)", "Prenez un selfie clair", _selfieFile, (f) => _selfieFile = f),
          const SizedBox(height: 12),
          _buildDocUploadCard("Carte grise / Immatriculation", "Document du véhicule", _registrationFile, (f) => _registrationFile = f),
          const SizedBox(height: 12),
          _buildDocUploadCard("Assurance du véhicule (optionnel)", "En cours de validité", _insuranceFile, (f) => _insuranceFile = f),
          const SizedBox(height: 30),
          _buildButton("Soumettre mon dossier", _handleNextStep, loading: _isLoading),
          const SizedBox(height: 20),
        ],
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
            "Votre compte livreur a été soumis avec succès.\nNous vérifions vos informations sous peu.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildRecapRow("Nom complet", _nameController.text),
                const Divider(),
                _buildRecapRow("Téléphone", _phoneController.text),
                const Divider(),
                _buildRecapRow("Email", _emailController.text),
                const Divider(),
                _buildRecapRow("Moyen de livraison", _selectedVehicle),
                const Divider(),
                _buildRecapRow("Statut du dossier", "En attente de validation"),
              ],
            ),
          ),
          const Spacer(),
          _buildButton("Suivre ma demande", () {
            Navigator.of(context).pushNamedAndRemoveUntil('/partner_waiting', (route) => false);
          }),
          const SizedBox(height: 20),
        ],
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
          Text(value.isEmpty ? "-" : value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // --- HELPERS ---
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
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey, size: 18),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400], size: 18),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelector(String type, IconData icon) {
    bool isSelected = _selectedVehicle == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedVehicle = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF6F1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFFFF5722) : const Color(0xFFF2F2F5), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF5722) : Colors.black54, size: 28),
              const SizedBox(height: 8),
              Text(type, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocUploadCard(String title, String subtitle, File? file, Function(File) onSelected) {
    return InkWell(
      onTap: () => _showImageSourceDialog((f) => setState(() => onSelected(f))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: file != null ? Colors.green.shade200 : Colors.transparent, width: 1),
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
}
