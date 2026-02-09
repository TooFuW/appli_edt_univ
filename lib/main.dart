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
  runApp(const MyApp());
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
            String error = "";
            bool isLoading = false;
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    textH2(text: "Connexion en cours..."),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 36, 155, 252)),
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 10),
                    elevatedButton(
                      isLoading: isLoading,
                      onPressed: () async {
                        String? userId = await getInfo("id");
                        if (userId != null) {
                          isLoading = true;
                          String? calendar = await getInfo("calendar_$userId");
                          if (calendar != null) {
                            final iCalendar = ICalendar.fromString(calendar);
                            final lastConnexionString = await getInfo('lastSave_$userId');
                            final lastConnexion = lastConnexionString != null ? DateTime.parse(lastConnexionString) : null;
                            isLoading = false;
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => MyHomePage(
                                    calendar: iCalendar,
                                    id: userId,
                                    offline: true,
                                    lastConnexion: lastConnexion,
                                  ),
                                ),
                                (Route<dynamic> route) => false
                              );
                            }
                          }
                          else {
                            error = "Aucun calendrier sauvegardé pour $userId";
                            isLoading = false;
                          }
                        }
                        else {
                          error = "Aucun compte connecté";
                        }
                      },
                      text: "Se connecter sans internet"
                    ),
                    const SizedBox(height: 5),
                    error.isEmpty
                      ? const SizedBox.shrink()
                      : textError(text: error),
                  ],
                ),
              )
            );
          } else if (snapshot.hasError) {
            eraseStorage();
            return const LoginScreen();
          } else {
            return snapshot.data ?? const LoginScreen();
          }
        },
      ),
    );
  }

  Future<Widget> _autoConnect(BuildContext context) async {
    String? userId = await getInfo("id");
    String? calendar = await getInfo("ics_$userId");
    if (userId != null && calendar != null) {
      Uri url = Uri.parse(calendar);
      try {
        // RECEPTION DE LA REPONSE
        var response = await http.get(url);
        // Si la réponse est bonne
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final icsString = utf8.decode(bytes);
          final iCalendar = ICalendar.fromString(icsString);
          final idx = icsString.lastIndexOf('R');
          final toSave = (idx != -1 && idx < icsString.length - 1)
            ? icsString.substring(0, idx + 1)
            : icsString;
          await saveInfo('calendar_$userId', toSave);
          await saveInfo('lastSave_$userId', DateTime.now().toLocal().toString());
          return MyHomePage(calendar: iCalendar, id: userId);
        }
        // Sinon
        else {
          // On essaie de charger le calendrier enregistré
          String? calendar = await getInfo("calendar_$userId");
          if (calendar != null) {
            final iCalendar = ICalendar.fromString(calendar);
            final lastConnexionString = await getInfo('lastSave_$userId');
            final lastConnexion = lastConnexionString != null ? DateTime.parse(lastConnexionString) : null;
            return MyHomePage(calendar: iCalendar, id: userId, offline: true, lastConnexion: lastConnexion);
          }
          // Sinon page de login
          return const LoginScreen();
        }
      }
      // On gére le cas où il n'y a pas d'internet
      catch (e) {
        // On essaie de charger le calendrier enregistré
        final calendar = await getInfo("calendar_$userId");
        if (calendar != null) {
          final iCalendar = ICalendar.fromString(calendar);
          final lastConnexionString = await getInfo('lastSave_$userId');
          final lastConnexion = lastConnexionString != null ? DateTime.parse(lastConnexionString) : null;
          return MyHomePage(calendar: iCalendar, id: userId, offline: true, lastConnexion: lastConnexion);
        }
        // Sinon page de login
        return const LoginScreen();
      }
    }
    return const LoginScreen();
  }
}

// Gestion d'un ICS
class Event {
  final String title;
  final String categorie;
  final String professeur;
  final String salle;
  final String? description;
  final DateTime? start;
  final DateTime? end;

  const Event({
    required this.title,
    required this.categorie,
    required this.professeur,
    required this.salle,
    this.description,
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
  const MyHomePage({super.key, required this.calendar, required this.id, this.offline = false, this.lastConnexion});

  final ICalendar calendar;
  final String id;
  final bool offline;
  final DateTime? lastConnexion;

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
  late bool _weekVue;

  bool _isRefreshLoading = false;

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
      String? description;
      List<String>? splitDesc = (e['description'] as String?)?.split('\\n').first.split(') -');
      if (splitDesc != null && splitDesc.length > 1) {
        description = splitDesc[1];
      }
      else {
        splitDesc = (e['description'] as String?)?.split('\\n').first.split(')-');
        if (splitDesc != null && splitDesc.length > 1) {
          description = splitDesc[1];
        }
      }
      String categorie;
      if (description != null && (description.contains(" CC") || description.contains("CC "))) {
        categorie = "CC";
      }
      else if ((e['summary'] as String?)?.split(' ').first == "Cm" || (e['summary'] as String?)?.split(' ').first == "Td" || (e['summary'] as String?)?.split(' ').first == "Tp" || (e['summary'] as String?)?.split(' ').first == "Cc") {
        categorie = (e['summary'] as String).split(' ').first.toUpperCase();
      }
      else {
        categorie = "";
      }
      String title;
      if ((e['summary'] as String?)?.split('(').length == 1) {
        title = (e['summary'] as String).split('\\n').first.substring(0,2).toUpperCase() + (e['summary'] as String).split('\\n').first.substring(2);
        if (categorie == "CC") {
          title = title.replaceRange(0, 2, "CC");
        }
      }
      else {
        title = (e['summary'] as String).split('(').first.substring(0,2).toUpperCase() + (e['summary'] as String).split('(').first.substring(2);
        if (categorie == "CC") {
          title = title.replaceRange(0, 2, "CC");
        }
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
        description: description,
        start: start,
        end: end
      );
      _events.putIfAbsent(day, () => []).add(ev);
    }

    // 2. Initialiser la sélection
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _weekVue = MediaQuery.of(context).size.width > 800;
    _selectedEvents.value = MediaQuery.of(context).size.width > 800 ? _getEventsForWeek(_selectedDay!) : _getEventsForDay(_selectedDay!);
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
      if (!_weekVue) {
        _selectedEvents.value = _getEventsForDay(selectedDay);
      }
      else {
        _selectedEvents.value = _getEventsForWeek(selectedDay);
      }
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

  DateTime _getStartOfWeek(DateTime date) {
    // Calcule le lundi de la semaine du jour donné
    int daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  DateTime _getEndOfWeek(DateTime date) {
    // Calcule le dimanche de la semaine du jour donné
    int daysToSunday = 7 - date.weekday;
    return DateTime(date.year, date.month, date.day + daysToSunday);
  }

  List<Event> _getEventsForWeek(DateTime selectedDay) {
    final startOfWeek = _getStartOfWeek(selectedDay);
    final endOfWeek = _getEndOfWeek(selectedDay);
    
    final days = _daysInRange(startOfWeek, endOfWeek);
    final allEvents = <Event>[];
    
    for (final day in days) {
      final dayEvents = _getEventsForDay(day);
      allEvents.addAll(dayEvents);
    }
    
    // Trier tous les événements de la semaine par date puis par heure
    allEvents.sort((a, b) {
      if (a.start == null && b.start == null) return 0;
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      
      // Comparer d'abord par date
      final dateComparison = DateTime(a.start!.year, a.start!.month, a.start!.day)
          .compareTo(DateTime(b.start!.year, b.start!.month, b.start!.day));
      
      if (dateComparison != 0) return dateComparison;
      
      // Si même date, comparer par heure
      return a.start!.compareTo(b.start!);
    });
    
    return allEvents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EDT de ${widget.id}'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: MediaQuery.of(context).size.width > 800 ? [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.black,),
            tooltip: 'Mode semaine',
            onPressed: () {
              setState(() {
                _weekVue = !_weekVue;
                _rangeStart = null;
                _rangeEnd = null;
                _rangeSelectionMode = RangeSelectionMode.toggledOff;
                if (!_weekVue) {
                  _selectedEvents.value = _getEventsForDay(_focusedDay);
                }
                else {
                  _selectedEvents.value = _getEventsForWeek(_focusedDay);
                }
              });
            }
          ),
        ]
        : null
      ),
      drawer: SafeArea(
        child: Drawer(
          backgroundColor: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.blue,),
                title: const Text('Recharger', style: TextStyle(color: Colors.blue),),
                trailing: _isRefreshLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 36, 155, 252)),
                        backgroundColor: Colors.grey[300],
                      ),
                    )
                  : null,
                onTap: () async {
                  if (!_isRefreshLoading) {
                    setState(() {
                      _isRefreshLoading = true;
                    });
                    String? calendar = await getInfo("ics_${widget.id}");
                    Uri url = calendar != null ? Uri.parse(calendar) : Uri();
                    try {
                      // RECEPTION DE LA REPONSE
                      var response = await http.get(url);
                      // Si la réponse est bonne
                      if (response.statusCode == 200) {
                        final bytes = response.bodyBytes;
                        final icsString = utf8.decode(bytes);
                        final iCalendar = ICalendar.fromString(icsString);
                        final idx = icsString.lastIndexOf('R');
                        final toSave = (idx != -1 && idx < icsString.length - 1)
                          ? icsString.substring(0, idx + 1)
                          : icsString;
                        await saveInfo('calendar', toSave);
                        await saveInfo('lastSave', DateTime.now().toLocal().toString());
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => MyHomePage(calendar: iCalendar, id: widget.id),
                            ),
                            (Route<dynamic> route) => false
                          );
                        }
                      }
                      else {
                        // Sinon rien
                      }
                    }
                    catch (e) {
                      // Sinon rien
                    }
                    setState(() {
                      _isRefreshLoading = false;
                    });
                  }
                },
              ),
              const Divider(
                thickness: 1,
              ),
              ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.orange,),
                title: const Text('Changer de compte', style: TextStyle(color: Colors.orange),),
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false
                  );
                },
              ),
              const Divider(
                thickness: 1,
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red,),
                title: const Text('Se déconnecter', style: TextStyle(color: Colors.red),),
                onTap: () async {
                  await deleteInfo('id_${widget.id}');
                  await deleteInfo('ics_${widget.id}');
                  await deleteInfo('calendar_${widget.id}');
                  await deleteInfo('lastSave_${widget.id}');
                  String? accounts = await getInfo('accounts');
                  if (accounts != null)  {
                    List<dynamic> accountsList = json.decode(accounts);
                    accountsList.removeWhere((account) => account[0] == widget.id);
                    await saveInfo('accounts', json.encode(accountsList));
                  }
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (Route<dynamic> route) => false
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.offline)
              Container(
                color: Colors.red,
                width: double.infinity,
                padding: const EdgeInsets.all(5),
                child: Text(
                  widget.lastConnexion != null
                    ? 'Vous êtes hors-ligne depuis le ${DateFormat('dd/MM/yyyy à HH:mm').format(widget.lastConnexion!)}'
                    : 'Vous êtes hors-ligne',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            _CalendarHeader(
              focusedDay: _focusedDay.toLocal(),
              weekVue: _weekVue,
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
                  if (!_weekVue && _rangeSelectionMode == RangeSelectionMode.toggledOff) {
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
                rangeStartDecoration: BoxDecoration(color: const Color(0xFF6699FF), shape: BoxShape.circle, border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 1)),
                rangeEndDecoration: BoxDecoration(color: const Color(0xFF6699FF), shape: BoxShape.circle, border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 1)),
              ),
              locale: 'fr_FR',
              firstDay: DateTime.utc(DateTime.now().year, 1, 1),
              lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
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
              child: !_weekVue
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (DragEndDetails details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v > 0) {
                        _onDaySelected(DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day - 1), DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day - 1));
                      } else if (v < 0) {
                        _onDaySelected(DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + 1), DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + 1));
                      }
                    },
                    child: ValueListenableBuilder<List<Event>>(
                      valueListenable: _selectedEvents,
                      builder: (context, value, _) {
                        if (value.isEmpty) {
                          return Center(child: Text('Aucun événement pour le ${_focusedDay.day} ${_months[_focusedDay.month - 1]} ${_focusedDay.year}'));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: value.length,
                          itemBuilder: (context, index) {
                            final ev = value[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _EventTile(ev),
                                const SizedBox(height: 10),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (DragEndDetails details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v > 0) {
                        _onDaySelected(DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day - 7), DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day - 7));
                      } else if (v < 0) {
                        _onDaySelected(DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + 7), DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + 7));
                      }
                    },
                    child: ValueListenableBuilder<List<Event>>(
                      valueListenable: _selectedEvents,
                      builder: (context, value, _) {
                        if (value.isEmpty) {
                          final startOfWeek = _getStartOfWeek(_selectedDay ?? _focusedDay);
                          final endOfWeek = _getEndOfWeek(_selectedDay ?? _focusedDay);
                          return Center(
                            child: Text(
                              'Aucun événement pour la semaine du ${startOfWeek.day} ${_months[startOfWeek.month - 1]} au ${endOfWeek.day} ${_months[endOfWeek.month - 1]} ${endOfWeek.year}'
                            )
                          );
                        }
                        final Map<DateTime, List<Event>> eventsByDay = {};
                        for (final ev in value) {
                          final d = DateTime(ev.start!.year, ev.start!.month, ev.start!.day);
                          eventsByDay.putIfAbsent(d, () => []).add(ev);
                        }
                        final days = eventsByDay.keys.toList()..sort();
                        return SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final d in days)
                                _DayColumn(day: d, events: eventsByDay[d]!, days: days.length),
                            ],
                          ),
                        );
                      },
                    )
                  )
            ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<Event> events;
  final int days;
  static const List<String> _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  const _DayColumn({required this.day, required this.events, required this.days});

  @override
  Widget build(BuildContext context) {
    final dayName  = _jours[day.weekday - 1];
    final dayLabel = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
    return Container(
      width: (MediaQuery.of(context).size.width / days) - 24,
      margin: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$dayName $dayLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3C3C3C),
                )),
          ),
          const SizedBox(height: 8),
          for (final ev in events) ...[
            _EventTile(ev),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event ev;
  const _EventTile(this.ev);
  static const List<String> _months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

  @override
  Widget build(BuildContext context) {
    final time = ev.start != null && ev.end != null
        ? '${DateFormat('HH:mm').format(ev.start!)} - '
          '${DateFormat('HH:mm').format(ev.end!)}'
        : '';
    return ElevatedButton(
      onPressed: () {
        showDialog(
          barrierColor: const Color.fromARGB(150, 0, 0, 0),
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                ev.title,
                style: const TextStyle(
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
                  const SizedBox(height: 5),
                  textMoyenP2(text: 'Professeur: ${ev.professeur}', textAlign: TextAlign.left),
                  const SizedBox(height: 5),
                  textMoyenP2(text: 'Salle: ${ev.salle}', textAlign: TextAlign.left),
                  const SizedBox(height: 5),
                  textMoyenP2(text: 'Du ${DateFormat('dd').format(ev.start!) } ${_months[int.parse(DateFormat('MM').format(ev.start!)) - 1]} ${DateFormat('yyyy').format(ev.start!)}, ${DateFormat('HH:mm').format(ev.start!)}', textAlign: TextAlign.left),
                  const SizedBox(height: 5),
                  textMoyenP2(text: 'Au ${DateFormat('dd').format(ev.end!) } ${_months[int.parse(DateFormat('MM').format(ev.end!)) - 1]} ${DateFormat('yyyy').format(ev.end!)}, ${DateFormat('HH:mm').format(ev.end!)}', textAlign: TextAlign.left),
                  if (ev.description != null && ev.description!.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        textMoyenP2(text: 'Description: ${ev.description}', textAlign: TextAlign.left),
                      ]
                    )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
      style: ElevatedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: ev.categorie == 'TD'
          ? Colors.green
          : ev.categorie == 'TP'
            ? Colors.orange
            : ev.categorie == 'CM'
              ? Colors.blue
              : ev.categorie == 'CC'
                ? Colors.red
                : Colors.purple,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 30, top: 5, bottom: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textMoyenP1(text: ev.title, textAlign: TextAlign.left),
                Row(children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.black),
                  const SizedBox(width: 5),
                  textPetitP(text: time),
                ]),
                Row(children: [
                  const Icon(Icons.person, size: 18, color: Colors.black),
                  const SizedBox(width: 5),
                  textPetitP(text: ev.professeur),
                ]),
                Row(children: [
                  const Icon(Icons.place, size: 18, color: Colors.black),
                  const SizedBox(width: 5),
                  textPetitP(text: ev.salle),
                ]),
              ],
            ),
          ),
          if (ev.categorie.isNotEmpty)
            Positioned(
              top: 8,
              right: 0,
              child: Container(
                width: 30,
                height: 25,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    ev.categorie,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16
                    ),
                    textAlign: TextAlign.center
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final bool weekVue;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;
  final VoidCallback onTodayButtonTap;
  final VoidCallback onSwapButtonTap;
  final VoidCallback onCheckButtonTap;

  _CalendarHeader({
    required this.focusedDay,
    required this.weekVue,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    required this.onTodayButtonTap,
    required this.onSwapButtonTap,
    required this.onCheckButtonTap,
  });

  final List<String> _months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

  @override
  Widget build(BuildContext context) {
    String month;
    if (_months[focusedDay.month - 1].length < 4) {
      month = _months[focusedDay.month - 1].substring(0, 3);
    }
    else {
      month = _months[focusedDay.month - 1].substring(0, 4);
    }
    final year = focusedDay.year.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 125,
            child: Text(
              "$month $year",
              style: const TextStyle(fontSize: 26),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: onTodayButtonTap,
            tooltip: "Aujourd'hui",
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: onSwapButtonTap,
            tooltip: "Changer de vue",
          ),
          weekVue ? const Spacer() : IconButton(
            icon: const Icon(Icons.check_box, size: 20),
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