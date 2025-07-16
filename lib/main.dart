import 'dart:collection';
import 'package:appli_edt_univ/screens/login_screen.dart';
import 'package:appli_edt_univ/theme.dart';
import 'package:flutter/material.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  initializeDateFormatting().then((_) => runApp(MyApp()));
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
      home: LoginScreen(),
    );
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
  const MyHomePage({super.key, required this.calendar});

  final ICalendar calendar;

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
      final title = (e['summary'] as String?)?.split('(').first ?? 'Sans titre';
      String professeur;
      if ((e['summary'] as String?)?.split('\\n').length == 1) {
        professeur = "Professeur inconnu";
      }
      else {
        professeur = (e['summary'] as String).split('\\n')[1];

      }
      final salle = (e['summary'] as String?)?.split(': ').last.split("[").first ?? 'Salle inconnue';
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
    return _events[day] ?? [];
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    final days = _daysInRange(start, end);
    return [for (final d in days) ..._getEventsForDay(d)];
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
      appBar: AppBar(title: const Text('EDT Universitaire')),      
      body: Column(
        children: [
          _CalendarHeader(
            focusedDay: _focusedDay,
            onTodayButtonTap: () {
              setState(() {
                _focusedDay = DateTime.now().toLocal();
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
                                  title: Text(ev.title),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Categorie: ${ev.categorie}'),
                                      Text('Professeur: ${ev.professeur}'),
                                      Text('Salle: ${ev.salle}'),
                                      Text('Start: ${ev.start}'),
                                      Text('End: ${ev.end}'),
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
                              textMoyenP1(text: ev.title),
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
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;
  final VoidCallback onTodayButtonTap;
  final VoidCallback onSwapButtonTap;

  const _CalendarHeader({
    required this.focusedDay,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    required this.onTodayButtonTap,
    required this.onSwapButtonTap,
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
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20.0),
            visualDensity: VisualDensity.compact,
            onPressed: onSwapButtonTap,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onLeftArrowTap,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onRightArrowTap,
          ),
        ],
      ),
    );
  }
}