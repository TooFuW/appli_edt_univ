import 'dart:collection';
import 'dart:convert';
import 'package:appli_edt_univ/screens/login_screen.dart';
import 'package:appli_edt_univ/theme.dart';
import 'package:flutter/material.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await initStorage();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendrier Universitaire',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 36, 155, 252)),
        useMaterial3: true,
      ),
      home: FutureBuilder<Widget?>(
        future: _autoConnect(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    textH2(text: "Connexion en cours..."),
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Color.fromARGB(255, 36, 155, 252),
                      ),
                    ),
                    FutureBuilder<int>(
                      future: Future.delayed(const Duration(seconds: 5), () => 5),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return textMoyenP1(text: "Encore en chargement...", bold: true);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    FutureBuilder<int>(
                      future: Future.delayed(const Duration(seconds: 10), () => 10),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return textMoyenP1(text: "Nous avons du mal à nous connecter...", bold: true);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              )
            );
          } else if (snapshot.hasError) {
            eraseStorage();
            return LoginScreen();
          } else {
            return snapshot.data ?? LoginScreen();
          }
        },
      ),
    );
  }

  Future<Widget> _autoConnect(BuildContext context) async {
    String? userId = await getId();
    if (userId != null) {
      var url = Uri.parse('http://applis.univ-nc.nc/cgi-bin/WebObjects/EdtWeb.woa/2/wa/default').replace(queryParameters: {'login': '$userId/ical'});
      try {
        // RECEPTION DE LA REPONSE
        var response = await http.get(url);
        // Si la réponse est bonne
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final icsString = utf8.decode(bytes);
          final iCalendar = ICalendar.fromString(icsString);
          return MyHomePage(calendar: iCalendar, id: userId);
        }
        // Sinon
        else {
          return LoginScreen();
        }
      }
      // On gére le cas où il n'y a pas d'internet
      catch (e) {
        return LoginScreen();
      }
    }
    return LoginScreen();
  }
}

// Gestion d'un ICS
class Event {
  final String title;
  final String categorie;
  final String professeur;
  final String salle;
  final DateTime? start;
  final DateTime? end;

  const Event({
    required this.title,
    required this.categorie,
    required this.professeur,
    required this.salle,
    this.start,
    this.end
  });

  @override
  String toString() => title;
}

int _getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

List<DateTime> _daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.calendar, required this.id});

  final ICalendar calendar;
  final String id;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final LinkedHashMap<DateTime, List<Event>> _events;
  late final ValueNotifier<List<Event>> _selectedEvents;

  CalendarFormat _calendarFormat = CalendarFormat.week;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOff;
  DateTime _focusedDay = DateTime.now().toLocal();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  late PageController _pageController;

  final List<String> _months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

  @override
  void initState() {
    super.initState();

    // 1. Construire la map d'événements à partir de ICS
    _events = LinkedHashMap<DateTime, List<Event>>(
      equals: isSameDay,
      hashCode: _getHashCode,
    );
    for (var e in widget.calendar.data) {
      final IcsDateTime? rawStart = e['dtstart'] as IcsDateTime?;
      final IcsDateTime? rawEnd = e['dtend'] as IcsDateTime?;
      final dtStartUtc = rawStart?.toDateTime();
      final dtEndUtc = rawEnd?.toDateTime();
      final start = dtStartUtc?.toLocal();
      final end = dtEndUtc?.toLocal();
      String categorie;
      if ((e['summary'] as String?)?.split(' ').first == "Cm" || (e['summary'] as String?)?.split(' ').first == "Td" || (e['summary'] as String?)?.split(' ').first == "Tp") {
        categorie = (e['summary'] as String).split(' ').first;
      }
      else {
        categorie = "";
      }
      String title;
      if ((e['summary'] as String?)?.split('(').length == 1) {
        title = (e['summary'] as String).split('\\n').first;
      }
      else {
        title = (e['summary'] as String).split('(').first;
      }
      String professeur;
      if ((e['summary'] as String?)?.split('\\n').length == 1) {
        professeur = "Professeur inconnu";
      }
      else {
        professeur = (e['summary'] as String).split('\\n')[1].split("[").first;
      }
      String salle;
      if ((e['summary'] as String?)?.split(': ').last.split("[").first != null) {
        if ((e['summary'] as String).split(': ').last.split("[").first.length >= 2 && (e['summary'] as String).split(': ').last.split("[").first.length <= 17) {
          salle = (e['summary'] as String).split(': ').last.split("[").first;
        }
        else {
          salle = "Salle inconnue";
        }
      }
      else {
        salle = "Salle inconnue";
      }
      if (start == null) continue;
      final day = DateTime(start.year, start.month, start.day);
      final ev = Event(
        title: title,
        categorie: categorie,
        professeur: professeur,
        salle: salle,
        start: start,
        end: end
      );
      _events.putIfAbsent(day, () => []).add(ev);
    }

    // 2. Initialiser la sélection
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Event> _getEventsForDay(DateTime day) {
    final events = _events[day] ?? [];
    // Trier les événements par heure de début
    events.sort((a, b) {
      if (a.start == null && b.start == null) return 0;
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return a.start!.compareTo(b.start!);
    });
    return events;
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    final days = _daysInRange(start, end);
    final allEvents = [for (final d in days) ..._getEventsForDay(d)];
    // Trier tous les événements de la plage par heure de début
    allEvents.sort((a, b) {
      if (a.start == null && b.start == null) return 0;
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return a.start!.compareTo(b.start!);
    });
    return allEvents;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null;
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });
    if (start != null && end != null) {
      _selectedEvents.value = _getEventsForRange(start, end);
    } else if (start != null) {
      _selectedEvents.value = _getEventsForDay(start);
    } else if (end != null) {
      _selectedEvents.value = _getEventsForDay(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EDT de ${widget.id}'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      drawer: SafeArea(
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red,),
                title: Text('Se déconnecter', style: TextStyle(color: Colors.red),),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _CalendarHeader(
              focusedDay: _focusedDay,
              onTodayButtonTap: () {
                setState(() {
                  _onDaySelected(DateTime.now(), DateTime.now());
                });
              },
              onSwapButtonTap: () {
                if (_calendarFormat == CalendarFormat.week) {
                  setState(() => _calendarFormat = CalendarFormat.month);
                }
                else {
                  setState(() => _calendarFormat = CalendarFormat.week);
                }
              },
              onCheckButtonTap: () {
                setState(() {
                  if (_rangeSelectionMode == RangeSelectionMode.toggledOff) {
                    _onRangeSelected(_selectedDay, null, _focusedDay);
                  } else {
                    _onDaySelected(_focusedDay, _focusedDay);
                  }
                });
              },
              onLeftArrowTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              onRightArrowTap: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
            ),
            TableCalendar<Event>(
              onCalendarCreated: (controller) => _pageController = controller,
              headerVisible: false,
              calendarStyle: CalendarStyle(
                markerMargin: const EdgeInsets.only(left: 0.3, right: 0.3, top: 2),
                selectedDecoration: const BoxDecoration(color: Color.fromARGB(255, 67, 95, 255), shape: BoxShape.circle),
                todayDecoration: const BoxDecoration(color: Color.fromARGB(255, 151, 160, 209), shape: BoxShape.circle),
                rangeStartDecoration: BoxDecoration(color: Color(0xFF6699FF), shape: BoxShape.circle, border: Border.all(color: Color.fromARGB(255, 0, 0, 0), width: 1)),
                rangeEndDecoration: BoxDecoration(color: Color(0xFF6699FF), shape: BoxShape.circle, border: Border.all(color: Color.fromARGB(255, 0, 0, 0), width: 1)),
              ),
              locale: 'fr_FR',
              firstDay: DateTime.utc(_focusedDay.year, 1, 1),
              lastDay: DateTime.utc(_focusedDay.year + 1, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rangeSelectionMode: _rangeSelectionMode,
              eventLoader: _getEventsForDay,
              onDaySelected: _onDaySelected,
              onRangeSelected: _onRangeSelected,
              onFormatChanged: (_) {
                if (_calendarFormat == CalendarFormat.week) {
                  setState(() => _calendarFormat = CalendarFormat.month);
                }
                else {
                  setState(() => _calendarFormat = CalendarFormat.week);
                }
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<Event>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  if (value.isEmpty) {
                    return Center(child: Text('Aucun événement pour le ${_focusedDay.day} ${_months[_focusedDay.month - 1]} ${_focusedDay.year}'));
                  }
                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      final ev = value[index];
                      final time = ev.start != null && ev.end != null
                          ? '${DateFormat('HH:mm').format(ev.start!)} - '
                            '${DateFormat('HH:mm').format(ev.end!)}'
                          : '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                barrierColor: const Color.fromARGB(150, 0, 0, 0),
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: Text(
                                      ev.title,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold
                                      ),
                                      textAlign: TextAlign.center
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (ev.categorie.isNotEmpty) textMoyenP2(text: 'Categorie: ${ev.categorie}', textAlign: TextAlign.left),
                                        SizedBox(height: 5),
                                        textMoyenP2(text: 'Professeur: ${ev.professeur}', textAlign: TextAlign.left),
                                        SizedBox(height: 5),
                                        textMoyenP2(text: 'Salle: ${ev.salle}', textAlign: TextAlign.left),
                                        SizedBox(height: 5),
                                        textMoyenP2(text: 'Du ${_focusedDay.day} ${_months[_focusedDay.month - 1]} ${_focusedDay.year}, ${DateFormat('HH:mm').format(ev.start!)}', textAlign: TextAlign.left),
                                        SizedBox(height: 5),
                                        textMoyenP2(text: 'Au ${_focusedDay.day} ${_months[_focusedDay.month - 1]} ${_focusedDay.year}, ${DateFormat('HH:mm').format(ev.end!)}', textAlign: TextAlign.left),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Fermer'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.all(8.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: ev.categorie == 'Td'
                                ? Colors.green
                                : ev.categorie == 'Tp'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                textMoyenP1(
                                  text: ev.title,
                                  textAlign: TextAlign.left
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 18, color: Colors.black),
                                    SizedBox(width: 5),
                                    textPetitP(text: time),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 18, color: Colors.black),
                                    SizedBox(width: 5),
                                    textPetitP(text: ev.professeur),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.place, size: 18, color: Colors.black),
                                    SizedBox(width: 5),
                                    textPetitP(text: ev.salle),
                                  ],
                                ),
                              ],
                            )
                          ),
                          SizedBox(height: 10),
                        ],
                      );
                    },
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

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;
  final VoidCallback onTodayButtonTap;
  final VoidCallback onSwapButtonTap;
  final VoidCallback onCheckButtonTap;

  const _CalendarHeader({
    required this.focusedDay,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    required this.onTodayButtonTap,
    required this.onSwapButtonTap,
    required this.onCheckButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    final headerText = DateFormat.yMMM().format(focusedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 16.0),
          SizedBox(
            width: 120.0,
            child: Text(
              headerText,
              style: const TextStyle(fontSize: 26.0),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20.0),
            visualDensity: VisualDensity.compact,
            onPressed: onTodayButtonTap,
            tooltip: "Aujourd'hui",
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20.0),
            visualDensity: VisualDensity.compact,
            onPressed: onSwapButtonTap,
            tooltip: "Changer de vue",
          ),
          IconButton(
            icon: const Icon(Icons.check_box, size: 20.0),
            visualDensity: VisualDensity.compact,
            onPressed: onCheckButtonTap,
            tooltip: "Changer de mode de sélection",
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onLeftArrowTap,
            tooltip: "Page précédente",
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onRightArrowTap,
            tooltip: "Page suivante",
          ),
        ],
      ),
    );
  }
}