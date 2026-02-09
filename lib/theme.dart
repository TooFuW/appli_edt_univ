import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences _prefs;

// Initialisation du storage
Future<void> initStorage() async {
  _prefs = await SharedPreferences.getInstance();
}

// Récupération d'une info
Future<String?> getInfo(String key) async {
  return _prefs.getString(key);
}

// Suppression de tout ce qui est enregistré
Future<void> eraseStorage() async {
  await _prefs.clear();
}

// Sauvegarde locale d'une info
Future<void> saveInfo(String key, String data) async {
  await _prefs.setString(key, data);
}

// Suppression d'une info
Future<void> deleteInfo(String key) async {
  await _prefs.remove(key);
}

// Texte de titre au format H1
Text textH1 (
  {required String text,
  TextAlign? textAlign}
  ) {
  return Text(
    text,
    style: const TextStyle(
      color: Colors.black,
      fontSize: 35,
      fontWeight: FontWeight.bold,
    ),
    textAlign: textAlign ?? TextAlign.center
  );
}

// Texte de titre au format H2
Text textH2 (
  {required String text,
  TextAlign? textAlign}
  ) {
  return Text(
    text,
    style: const TextStyle(
      color: Colors.black,
      fontSize: 30,
      fontWeight: FontWeight.bold,
    ),
    textAlign: textAlign ?? TextAlign.center,
  );
}

// Gros texte au format p
Text textGrosP (
  {required String text,
  TextAlign? textAlign,
  bool bold = false}
  ) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.black,
      fontSize: 20,
      fontWeight: bold
        ? FontWeight.bold
        : null,
    ),
    textAlign: textAlign ?? TextAlign.center,
  );
}

// Moyen texte au format p
Text textMoyenP1 (
  {required String text,
  TextAlign? textAlign,
  bool bold = false}
  ) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.black,
      fontSize: 18,
      fontWeight: bold
        ? FontWeight.bold
        : null,
    ),
    textAlign: textAlign ?? TextAlign.center,
  );
}

// Moyen texte au format p
Text textMoyenP2 (
  {required String text,
  TextAlign? textAlign,
  bool bold = false}
  ) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: bold
        ? FontWeight.bold
        : null,
    ),
    textAlign: textAlign ?? TextAlign.center,
  );
}

// Petit texte au format p
Text textPetitP (
  {required String text,
  TextAlign? textAlign,
  bool bold = false,}
  ) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: bold
        ? FontWeight.bold
        : null,
    ),
    textAlign: textAlign ?? TextAlign.center,
  );
}

// Mini texte au format p
Text textMiniP (
  {required String text,
  TextAlign? textAlign,
  bool bold = false}
  ) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.black,
      fontSize: 12,
      fontWeight: bold
        ? FontWeight.bold
        : null,
    ),
    textAlign: textAlign ?? TextAlign.center,
  );
}

// Texte d'erreur
Text textError (
  {required String text,
  TextAlign? textAlign}
  ) {
  return Text(
    text,
    style: const TextStyle(
      color: Colors.red,
      fontSize: 14,
      fontWeight: FontWeight.bold
    ),
    textAlign: textAlign ?? TextAlign.center
  );
}

// Petite SizedBox
SizedBox sizedBoxPetite () {
  return const SizedBox(height: 15);
}

// Grosse SizedBox
SizedBox sizedBoxGrosse () {
  return const SizedBox(height: 30);
}

// Champs de texte
StatefulBuilder textFormField({
  required TextEditingController controller,
  FocusNode? focusNode,
  required TextInputAction textInputAction,
  required Function(String) onFieldSubmitted,
  String? hintText,
  Iterable<String>? autofillHints,
  Icon? prefixIcon,
  IconButton? suffixIcon,
  bool? passwordVisible,
  required TextInputType keyboardType,
  required String? Function(String?)? validator,
  Function? onChanged,
}) {
  return StatefulBuilder(
    builder: (BuildContext context, StateSetter setState) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: (value) {
          if (onChanged != null) onChanged(value);
          setState(() {});
        },
        obscureText: passwordVisible != null ? !passwordVisible! : false,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          contentPadding: prefixIcon == null
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 0)
            : const EdgeInsets.all(0),
          prefixIcon: prefixIcon,
          suffixIcon: passwordVisible == null
            ? controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black),
                  onPressed: () {
                    controller.clear();
                    if (onChanged != null) onChanged("");
                    setState(() {});
                  },
                )
              : null
            : IconButton(
                icon: Icon(
                  passwordVisible!
                  ? Icons.visibility
                  : Icons.visibility_off,
                  color: const Color.fromARGB(255, 36, 155, 252),
                  size: 25,
                  ),
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onPressed: () {
                  setState(() {
                      passwordVisible = !passwordVisible!;
                  });
                },
                  ),
          filled: true,
          fillColor: Colors.grey.shade100,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(50),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color.fromARGB(255, 36, 155, 252), width: 2),
            borderRadius: BorderRadius.circular(50),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(50),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      );
    },
  );
}

// Gros boutons
ElevatedButton elevatedButton (
  {required Function() onPressed,
  required String text,
  bool isLoading = false,
  bool elevation = true,
  bool bigger = false}
) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      backgroundColor: const Color.fromARGB(255, 36, 155, 252),
      padding: bigger
        ? const EdgeInsets.symmetric(vertical: 10, horizontal: 10)
        : const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      elevation: elevation ? 5 : 0,
    ),
    child: isLoading
      ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator.adaptive(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 36, 155, 252)),
            backgroundColor: Colors.grey[300],
          ),
        )
      : textGrosP(
        text: text
      ),
  );
}