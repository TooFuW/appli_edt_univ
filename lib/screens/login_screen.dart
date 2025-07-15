import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  final List<FocusNode> focusNodes;
  
  const LoginScreen({
    super.key,
    required this.focusNodes,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Préparation du préchargement des images
  final AssetImage iconLogin = const AssetImage("assets/images/login_icon.png");

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _passwordVisible = false;

  bool _isLoading = false;
  String loginError = '';

  @override
  void dispose() {
    super.dispose();
    _emailController.dispose();
    _passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Précharger les images
    precacheImage(iconLogin, context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Form(
              // Associe la clé au formulaire
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image(
                    image: iconLogin,
                    height: 200,
                  ),
                  Text(text: "Connectez-vous"),
                  sizedBoxGrosse(),
                  // Champs d'email
                  textFormField(
                    controller: _emailController,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (value) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.mail),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre e-mail.';
                      }
                      return null;
                    }
                  ),
                  sizedBoxPetite(),
                  // Champs de mot de passe
                  textFormField(
                    controller: _passwordController,
                    autofillHints: const [AutofillHints.password],
                    focusNode: _passwordFocusNode,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (value) {
                      if (!_isLoading) {
                        _submitForm(context);
                      }
                    },
                    hintText: "Mot de passe",
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                        color: AppTheme.secondary,
                        size: 25,
                        ),
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onPressed: () {
                        setState(() {
                            _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    passwordVisible: _passwordVisible,
                    keyboardType: TextInputType.visiblePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre mot de passe.';
                      }
                      return null;
                    }
                  ),
                  sizedBoxPetite(),
                  // Bouton de connexion
                  elevatedButton(
                    onPressed: _isLoading
                      ? (){}
                      : () {
                          _submitForm(context);
                        },
                    text: "Se connecter",
                    isLoading: _isLoading
                  ),
                  // Message d'erreur
                  if (loginError.isNotEmpty)
                    Column(
                      children: [
                        sizedBoxPetite(),
                        Center(
                          child: textError(
                            text: loginError,
                            textAlign: TextAlign.center
                          )
                        ),
                      ],
                    ),
                  sizedBoxPetite(),
                  _forgotPassword(context),
                  _signup(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
void _submitForm(BuildContext context) async {
    // Vérification du formulaire
    if (_formKey.currentState!.validate() && !_isLoading) {
      // Si le formulaire est valide
      setState(() {
        _isLoading = true;
      });
      loginError = "";
      // ENVOI DE LA REQUETE DE CONNEXION
      Map<String, dynamic> data = {
        "email": _emailController.text,
        "password": _passwordController.text
      };
      var url = getUrl("/API/users/login");
      try {
        // RECEPTION DE LA REPONSE
        var response = await http.post(url, body: data);
        var responseBody = jsonDecode(response.body);
        // Si la réponse contient une erreur on affiche le message correspondant
        if (responseBody["error"] != null) {
          String jsonString = await rootBundle.loadString('assets/json/error_codes.json');
          Map<String, String> jsonMap = Map<String, String>.from(jsonDecode(jsonString));
          loginError = jsonMap[responseBody["error"].toString()] ?? responseBody["error"].toString();
        }
        // Sinon on sauvegarde les identifiants et on redirige vers la page d'accueil
        else {
          Map<String, dynamic> decodedToken = JwtDecoder.decode(responseBody["token"].toString());
          await saveLocally(
            [
              ["token", responseBody["token"].toString()],
              ["userId", decodedToken["userId"].toString()],
              ["name", responseBody["name"].toString()],
              ["surname", responseBody["surname"].toString()],
              ["email", _emailController.text],
              ["password", _passwordController.text],
              ["type", decodedToken["type"].toString()],
              ["permission", decodedToken["permission"].toString()],
              ["qrcodeId", responseBody["qrcodeId"].toString()],
              ["notifications", "true"]
            ]
          );
          if (decodedToken["type"].toString() == "2" && decodedToken["permission"].toString() == "3") {
            // On récupère les infos générales de l'utilisateur à afficher et on les sauvegarde
            List<Map<String, dynamic>> cartesFidelite = await getFidelityCards(responseBody["token"].toString(), decodedToken["userId"].toString());
            List<Map<String, dynamic>> recompenses = await getRecompenses(responseBody["token"].toString(), decodedToken["userId"].toString());
            List<Map<String, dynamic>> sponsos = await getSponsors();
            List<Map<String, dynamic>> offres = await getOffres();
            await saveLocally(
              [
                ["cartesFidelite", jsonEncode(cartesFidelite)],
                ["recompenses", jsonEncode(recompenses)],
                ["sponsos", jsonEncode(sponsos)],
                ["offres", jsonEncode(offres)]
              ]
            );
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => MyApp(),
                ),
                (Route<dynamic> route) => false,
              );
            }
          }
          else {
            loginError = "Utilisez l'application Bonus Pro pour votre compte d'établissement. Vous utilisez Bonus qui est fait pour les clients.";
          }
        }
        setState(() {
          _isLoading = false;
        });
      }
      // On gére le cas où il n'y a pas d'internet
      catch (e) {
        loginError = "Veuillez vérifier votre connexion internet et réessayer.";
        setState(() {
          _isLoading = false;
        });
      }
      
    }
  }

  _forgotPassword(context) {
    // Zone qui renvoie vers la page de réinitialisation de mot de passe
    return textButton(
      onPressed: _isLoading
        ? (){}
        : () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (BuildContext context) => ResetPasswordScreen()),
        );
      },
      text: "Mot de passe oublié ?"
    );
  }

  _signup(context) {
    // Zone qui renvoie vers la page de création de compte
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: textPetitP(
            text: "Pas encore de compte ? "
          ),
        ),
        Flexible(
          child: textButton(
            onPressed: _isLoading
              ? (){}
              : () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (BuildContext context) => RegisterScreen(focusNodes: widget.focusNodes)),
                (Route<dynamic> route) => false,
              );
            },
            text: "Créer un compte"
          ),
        )
      ],
    );
  }
}