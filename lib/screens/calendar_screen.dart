import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/media_service.dart';
import '../widgets/media_calendar_item.dart';
import 'media_viewer_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaService>(
      builder: (context, mediaService, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Calendar View'),
          ),
          body: Column(
            children: [
              _buildCalendar(mediaService),
              Expanded(
                child: _buildDayMedia(mediaService),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendar(MediaService mediaService) {
    return TableCalendar(
      firstDay: DateTime.utc(2000, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      eventLoader: (day) {
        // Return media items for this day
        final dateOnly = DateTime(day.year, day.month, day.day);
        return mediaService.mediaByDate[dateOnly] ?? [];
      },
      calendarStyle: CalendarStyle(
        markersMaxCount: 3,
        markersAlignment: Alignment.bottomCenter,
        markerDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildDayMedia(MediaService mediaService) {
    if (_selectedDay == null) {
      return Container();
    }

    final dateOnly =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final mediaForDay = mediaService.mediaByDate[dateOnly] ?? [];

    if (mediaForDay.isEmpty) {
      return Center(
        child: Text('No media for this day'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Media from ${_formatDate(_selectedDay!)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _calculateColumnCount(context),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: mediaForDay.length,
            itemBuilder: (context, index) {
              final mediaItem = mediaForDay[index];
              return MediaCalendarItem(
                mediaItem: mediaItem,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MediaViewerScreen(
                        mediaItem: mediaItem,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _calculateColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 6;
    } else if (width > 900) {
      return 5;
    } else if (width > 600) {
      return 4;
    } else {
      return 3;
    }
  }
}
