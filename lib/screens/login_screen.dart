import 'dart:convert';
import 'package:appli_edt_univ/main.dart';
import 'package:appli_edt_univ/theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.debug});

  final String? debug;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Préparation du préchargement des images
  final AssetImage iconLogin = const AssetImage("assets/images/login_icon.png");

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _idController = TextEditingController();

  bool _isLoading = false;

  String loginError = "";

  List<dynamic> accounts = [];

  @override
  void initState() {
    super.initState();
    if (widget.debug != null) {
      loginError = widget.debug!;
    }
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    String? accountsRaw = await getInfo('accounts');
    if (accountsRaw != null) {
      setState(() {
        accounts = jsonDecode(accountsRaw);
      });
    } else {
      setState(() {
        accounts = [];
      });
    }
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
      body: SafeArea(
        child: SingleChildScrollView(
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
                    textH1(text: "CONNECTEZ-VOUS"),
                    sizedBoxPetite(),
                    textMoyenP2(text: "Il vous suffit de rentrer votre identifiant universitaire pour vous connecter."),
                    textMoyenP2(text: "Votre identifiant correspond normalement à la première lettre de votre prénom suivi de votre nom."),
                    sizedBoxGrosse(),
                    // Champs d'email
                    textFormField(
                      controller: _idController,
                      autofillHints: const [AutofillHints.username],
                      hintText: "Identifiant universitaire",
                      prefixIcon: const Icon(Icons.person),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) {
                        _submitForm(context);
                      },
                      keyboardType: TextInputType.name,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre identifiant universitaire.';
                        }
                        return null;
                      }
                    ),
                    sizedBoxPetite(),
                    elevatedButton(
                      onPressed: () => _submitForm(context),
                      text: "Se connecter",
                      isLoading: _isLoading
                    ),
                    sizedBoxPetite(),
                    if (loginError.isNotEmpty)
                      textError(text: loginError),
                    if (loginError.isNotEmpty)
                      sizedBoxPetite(),
                    if (accounts.isNotEmpty)
                      textMoyenP2(
                        text: "Autres comptes (fonctionnent sans connexion) :",
                        textAlign: TextAlign.left
                      ),
                    if (accounts.isNotEmpty)
                      sizedBoxPetite(),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _idController.text = accounts[index];
                              _submitForm(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    child: Text(accounts[index][0]),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      accounts[index],
                                      style: const TextStyle(fontSize: 14),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
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
      // ENVOI DE LA REQUETE DE RECUPERATION DE L'EDT
      var url = Uri.parse('http://applis.univ-nc.nc/cgi-bin/WebObjects/EdtWeb.woa/2/wa/default').replace(queryParameters: {'login': '${_idController.text}/ical'});
      try {
        // RECEPTION DE LA REPONSE
        var response = await http.get(url);
        // Si la réponse est bonne
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final icsString = utf8.decode(bytes);
          final iCalendar = ICalendar.fromString(icsString);
          await saveInfo('id', _idController.text);
          final idx = icsString.lastIndexOf('R');
          final toSave = (idx != -1 && idx < icsString.length - 1)
            ? icsString.substring(0, idx + 1)
            : icsString;
          await saveInfo('calendar_${_idController.text}', toSave);
          await saveInfo('lastSave_${_idController.text}', DateTime.now().toLocal().toString());
          String? accounts = await getInfo('accounts');
          if (accounts == null) {
            await saveInfo('accounts', '[]');
          }
          else {
            List<dynamic> accountsList = json.decode(accounts);
            if (!accountsList.contains(_idController.text)) {
              accountsList.add(_idController.text);
              await saveInfo('accounts', json.encode(accountsList));
            }
          }
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => MyHomePage(calendar: iCalendar, id: _idController.text)),
              (Route<dynamic> route) => false
            );
          }
        }
        // Sinon
        else {
          loginError = "Veuillez vérifier l'identifiant entré et réessayez.";
        }
        setState(() {
          _isLoading = false;
        });
      }
      // On gére le cas où il n'y a pas d'internet
      catch (e) {
        String? accounts = await getInfo('accounts');
        if (accounts != null && json.decode(accounts).contains(_idController.text)) {
          String? calendar = await getInfo("calendar_${_idController.text}");
          if (calendar != null) {
            final iCalendar = ICalendar.fromString(calendar);
            final lastConnexionString = await getInfo('lastSave_${_idController.text}');
            final lastConnexion = lastConnexionString != null ? DateTime.parse(lastConnexionString) : null;
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => MyHomePage(calendar: iCalendar, id: _idController.text, offline: true, lastConnexion: lastConnexion)),
                (Route<dynamic> route) => false
              );
            }
          }
        }
        setState(() {
          _isLoading = false;
        });
        loginError = "Veuillez vérifier votre connexion internet et réessayez.";
      }
      
    }
  }
}