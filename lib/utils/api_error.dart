/// Message d'erreur présentable à l'utilisateur.
///
/// Le message renvoyé par le serveur n'est utilisé que si la réponse est
/// un vrai payload applicatif de l'API (présence de la clé 'success' au
/// premier niveau du JSON). Sinon — route Laravel introuvable (404
/// générique du framework), erreur 500, réponse d'un proxy/CDN, etc. —
/// le texte brut ne doit jamais s'afficher tel quel : ce n'est pas un
/// message destiné à l'utilisateur final (pas traduit, jargon technique).
String apiErrorMessage(Map<String, dynamic> data, String fallback) {
  if (data.containsKey('success') && data['message'] is String && (data['message'] as String).isNotEmpty) {
    return data['message'] as String;
  }
  return fallback;
}
