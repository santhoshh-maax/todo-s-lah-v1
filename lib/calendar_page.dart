import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;

  const CalendarPage({super.key, required this.tasks});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Map<String, dynamic>> _getTasksForDay(DateTime day) {
    final selectedDate = DateFormat('dd/MM/yyyy').format(day);

    return widget.tasks.where((task) {
      final repeat = task['repeat'] ?? 'None';

      try {
        final taskDate = DateFormat('dd/MM/yyyy').parse(task['date']);

        if (task['date'] == selectedDate) return true;
        if (repeat == 'Daily') return true;
        if (repeat == 'Weekly') {
          return taskDate.weekday == day.weekday;
        }
      } catch (e) {
        print("⚠️ Skipping task with invalid date: ${task['date']}");
      }

      return false;
    }).toList();
  }

  String _getEmoji(String title) {
    title = title.toLowerCase();

    if (title.contains('doctor') || title.contains('hospital') || title.contains('clinic')) {
      return '⚕️';
    } else if (title.contains('cook') || title.contains('kitchen') || title.contains('food')) {
      return '🍳';
    } else if (title.contains('bus') || title.contains('travel') || title.contains('trip')) {
      return '🚌';
    } else if (title.contains('class') || title.contains('study') || title.contains('school')) {
      return '📚';
    } else if (title.contains('call') || title.contains('phone') || title.contains('meeting')) {
      return '📞';
    } else if (title.contains('birthday') || title.contains('party') || title.contains('celebrate')) {
      return '🎉';
    } else if (title.contains('gym') || title.contains('workout') || title.contains('exercise')) {
      return '💪';
    } else if (title.contains('shopping') || title.contains('buy') || title.contains('grocery')) {
      return '🛒';
    } else if (title.contains('clean') || title.contains('wash') || title.contains('laundry')) {
      return '🧹';
    } else if (title.contains('exam') || title.contains('test') || title.contains('quiz')) {
      return '📝';
    } else if (title.contains('flight') || title.contains('airport') || title.contains('plane')) {
      return '✈️';
    } else if (title.contains('movie') || title.contains('film') || title.contains('cinema')) {
      return '🎬';
    } else if (title.contains('meditate') || title.contains('relax') || title.contains('calm')) {
      return '🧘';
    } else if (title.contains('medicine') || title.contains('pill') || title.contains('tablet')) {
      return '💊';
    } else if (title.contains('walk') || title.contains('jog') || title.contains('run')) {
      return '🚶';
    } else if (title.contains('water') || title.contains('plant')) {
      return '💧';
    } else if (title.contains('code') || title.contains('flutter') || title.contains('project')) {
      return '💻';
    } else {
      return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> selectedTasks = _getTasksForDay(
      _selectedDay ?? _focusedDay,
    );

    return Scaffold(
      appBar: AppBar(title: Text('📅 Calendar View')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ToggleButtons(
                isSelected: [
                  _calendarFormat == CalendarFormat.month,
                  _calendarFormat == CalendarFormat.week,
                ],
                onPressed: (index) {
                  setState(() {
                    _calendarFormat = index == 0
                        ? CalendarFormat.month
                        : CalendarFormat.week;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white,
                fillColor: const Color.fromARGB(255, 25, 118, 210),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("📆 Month"),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("📅 Week"),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              final selectedDate = DateFormat('dd/MM/yyyy').format(day);
              return widget.tasks
                  .where((task) => task['date'] == selectedDate)
                  .map((task) => _getEmoji(task['title']))
                  .toList();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 7,
              markerMargin: EdgeInsets.only(top: 4),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
           // inside TableCalendar widget
calendarBuilders: CalendarBuilders(
  //  markerBuilder MUST be inside CalendarBuilders
  markerBuilder: (context, date, events) {
    if (events.isEmpty) return null; // table_calendar expects null or a widget

    return Positioned(
      bottom: 1,
      child: Container(
        width: 40, 
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: events.take(3).map((event) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: Text(
                  event.toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  },
),
          ),
          Expanded(
            child: selectedTasks.isEmpty
                ? Center(child: Text('No tasks for selected date.'))
                : ListView.builder(
                    itemCount: selectedTasks.length,
                    itemBuilder: (context, index) {
                      final task = selectedTasks[index];
                      final emoji = _getEmoji(task['title']);
                      return ListTile(
                        leading: Text(
                          emoji,
                          style: TextStyle(fontSize: 24),
                        ),
                        title: Text(task['title']),
                        subtitle: Text(task['time']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
