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
  final _icsController = TextEditingController();

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        textMoyenP2(text: "Pour vous connecter à votre emploi du temps, veuillez entrer votre lien de calendrier ICS."),
                        IconButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Comment récupérer le lien de calendrier ICS ?"),
                                content: const Text("- Connectez-vous au site de l'EDT (https://edt.unc.nc/)\n- Sélectionnez le calendrier de votre choix\n- Cliquez sur le bouton de téléchargement puis sur celui nommé 'ICS' qui apparaîtra."),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Fermer'),
                                  ),
                                ],
                              );
                            },
                          ),
                          icon: const Icon(Icons.help, size: 18),
                        ),
                      ],
                    ),
                    textError(text: "ATTENTION, IL NE PEUT PAS Y AVOIR DEUX CALENDRIERS AVEC LE MÊME NOM, LE DERNIER UTILISÉ REMPLACERA LE PRÉCÉDENT."),
                    sizedBoxGrosse(),
                    // Champs de nommage
                    textFormField(
                      controller: _idController,
                      autofillHints: const [AutofillHints.username],
                      hintText: "Nom du calendrier (ex: 'Informatique', 'Yanis', ...)",
                      prefixIcon: const Icon(Icons.person),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (value) {
                        FocusScope.of(context).nextFocus();
                      },
                      keyboardType: TextInputType.name,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez nommer votre calendrier.';
                        }
                        return null;
                      }
                    ),
                    sizedBoxPetite(),
                    // Champs de lien ICS
                    textFormField(
                      controller: _icsController,
                      autofillHints: const [AutofillHints.url],
                      hintText: "Lien de calendrier ICS",
                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) {
                        _submitForm(context);
                      },
                      keyboardType: TextInputType.name,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre lien de calendrier ICS.';
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
                    loginError.isEmpty
                      ? sizedBoxPetite()
                      : textError(text: loginError),
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
                              _idController.text = accounts[index][0];
                              _icsController.text = accounts[index][1];
                              _submitForm(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    child: Text(accounts[index][0][0].toUpperCase()),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      accounts[index][0],
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
      Uri url = Uri.parse(_icsController.text);
      try {
        // RECEPTION DE LA REPONSE
        var response = await http.get(url);
        // Si la réponse est bonne
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final icsString = utf8.decode(bytes);
          final iCalendar = ICalendar.fromString(icsString);
          await saveInfo('id', _idController.text);
          await saveInfo('ics_${_idController.text}', _icsController.text);
          final idx = icsString.lastIndexOf('R');
          final toSave = (idx != -1 && idx < icsString.length - 1)
            ? icsString.substring(0, idx + 1)
            : icsString;
          await saveInfo('calendar_${_idController.text}', toSave);
          await saveInfo('lastSave_${_idController.text}', DateTime.now().toLocal().toString());
          String? accounts = await getInfo('accounts');
          if (accounts == null || accounts.runtimeType != List<List<String>>) {
            List<List<String>> accountsList = [];
            accountsList.add(<String>[_idController.text, _icsController.text]);
            await saveInfo('accounts', json.encode(accountsList));
          }
          else {
            List<dynamic> accountsList = json.decode(accounts);
            if (!accountsList.any((account) => account[0] == _idController.text)) {
              accountsList.add(<String>[_idController.text, _icsController.text]);
            } else {
              accountsList = accountsList.map((account) {
                if (account[0] == _idController.text) {
                  return <String>[_idController.text, _icsController.text];
                }
                return account;
              }).toList();
            }
            await saveInfo('accounts', json.encode(accountsList));
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
          loginError = "Veuillez vérifier le lien de calendrier ICS entré et réessayez.";
        }
        setState(() {
          _isLoading = false;
        });
      }
      // On gére le cas où il n'y a pas d'internet
      catch (e) {
        String? accounts = await getInfo('accounts');
        if (accounts != null && json.decode(accounts).any((account) => account[0] == _idController.text)) {
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