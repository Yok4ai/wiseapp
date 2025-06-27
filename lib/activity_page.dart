import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'settings_page.dart';
import 'leave_application_page.dart';
import 'user_data_manager.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> currentActivity = [];
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  bool _hasCheckedInToday = false;
  bool _hasCheckedOutToday = false;
  String _currentWorkingHours = '0h 0m';
  Timer? _updateTimer;
  String? _userEmail;

  // Mock attendance data for table
  final List<Map<String, dynamic>> attendanceData = [
    {
      'date': '27',
      'day': 'Fri',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '26',
      'day': 'Thu',
      'status': 'Absent',
      'inTime': '',
      'outTime': '',
      'hours': '',
    },
    {
      'date': '25',
      'day': 'Wed',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '24',
      'day': 'Tue',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '23',
      'day': 'Mon',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '22',
      'day': 'Sun',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '21',
      'day': 'Sat',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '20',
      'day': 'Fri',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '19',
      'day': 'Thu',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '18',
      'day': 'Wed',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '17',
      'day': 'Tue',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '16',
      'day': 'Mon',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '15',
      'day': 'Sun',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
    {
      'date': '14',
      'day': 'Sat',
      'status': 'Present',
      'inTime': '09:15am',
      'outTime': '7:00pm',
      'hours': '9.03',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserEmail().then((_) {
      _loadCurrentActivity();
      _loadTodayStatus();
    });
    _startUpdateTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_checkInTime != null && _checkOutTime == null) {
        _updateWorkingHours();
      }
    });
  }

  Future<void> _refreshData() async {
    await _loadCurrentActivity();
    await _loadTodayStatus();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      Map<String, dynamic> profile;
      if (token == 'dev_mock_token_for_ui_testing') {
        profile = await UserDataManager.instance.getProfile();
      } else {
        // If you have a profile fetcher, use it here
        profile = {};
      }
      _userEmail = profile['email'] ?? 'unknown';
    } else {
      _userEmail = 'unknown';
    }
  }

  Future<void> _loadCurrentActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = _userEmail ?? 'unknown';
    final String? activityJson = prefs.getString('current_activity_$userKey');
    if (activityJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(activityJson);
        setState(() {
          currentActivity = decoded.cast<Map<String, dynamic>>();
        });
      } catch (e) {
        print('Error loading activity: $e');
      }
    }
  }

  Future<void> _loadTodayStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.day}-${today.month}-${today.year}';
    final userKey = _userEmail ?? 'unknown';
    setState(() {
      _hasCheckedInToday =
          prefs.getBool('checkedIn_${userKey}_$todayKey') ?? false;
      _hasCheckedOutToday =
          prefs.getBool('checkedOut_${userKey}_$todayKey') ?? false;
    });
    final checkInTimeStr = prefs.getString('checkInTime_${userKey}_$todayKey');
    final checkOutTimeStr = prefs.getString(
      'checkOutTime_${userKey}_$todayKey',
    );
    if (checkInTimeStr != null) {
      _checkInTime = DateTime.tryParse(checkInTimeStr);
    }
    if (checkOutTimeStr != null) {
      _checkOutTime = DateTime.tryParse(checkOutTimeStr);
    }
    _updateWorkingHours();
  }

  void _updateWorkingHours() {
    if (_checkInTime != null) {
      final endTime = _checkOutTime ?? DateTime.now();
      final duration = endTime.difference(_checkInTime!);
      final totalMinutes = duration.inMinutes;
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;

      if (hours == 0 && minutes == 0) {
        setState(() {
          _currentWorkingHours = '0.00';
        });
      } else {
        final decimalHours = (totalMinutes / 60);
        setState(() {
          _currentWorkingHours = decimalHours.toStringAsFixed(2);
        });
      }
    } else {
      setState(() {
        _currentWorkingHours = '0.00';
      });
    }
  }

  String _formatTimeAMPM(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'pm' : 'am';

    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString()}:${minute.toString().padLeft(2, '0')}$period';
  }

  String _getDayLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(activityDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return '$difference days ago';
    }
  }

  List<Map<String, dynamic>> get dynamicAttendanceData {
    final now = DateTime.now();
    final todayData = {
      'date': now.day.toString(),
      'day': _getDayName(now.weekday),
      'status': _hasCheckedInToday ? 'Present' : 'Absent',
      'inTime': _checkInTime != null ? _formatTimeAMPM(_checkInTime!) : '',
      'outTime': _checkOutTime != null ? _formatTimeAMPM(_checkOutTime!) : '',
      'hours': _hasCheckedInToday ? _currentWorkingHours : '',
    };

    // Replace today's data (first item) with real data
    final updatedData = List<Map<String, dynamic>>.from(attendanceData);
    if (updatedData.isNotEmpty) {
      updatedData[0] = todayData;
    }

    return updatedData;
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  void _showLeaveTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Leave Type',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Color(0xFF0C0E11),
                  ),
                ),
                const SizedBox(height: 20),
                _LeaveTypeButton(
                  title: 'Casual Leave',
                  color: Colors.blue,
                  icon: Icons.event_available,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LeaveApplicationPage(
                          leaveType: 'Casual Leave',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _LeaveTypeButton(
                  title: 'Sick Leave',
                  color: Colors.red,
                  icon: Icons.local_hospital,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LeaveApplicationPage(leaveType: 'Sick Leave'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _LeaveTypeButton(
                  title: 'Leave with Pay',
                  color: Colors.green,
                  icon: Icons.paid,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LeaveApplicationPage(
                          leaveType: 'Leave with Pay',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header with time indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'General 9:00AM to 7:00PM',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Today,',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                        color: Color(0xFF0C0E11),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentWorkingHours,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: Color(0xFF0C0E11),
                      ),
                    ),
                  ],
                ),
              ),

              // Attendance Table
              Container(
                height: 520,
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              'Date',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              'Day',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              'In',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              'Out',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Hours',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Content
                    Expanded(
                      child: ListView.builder(
                        itemCount: dynamicAttendanceData.length,
                        itemBuilder: (context, index) {
                          final data = dynamicAttendanceData[index];
                          Color statusColor = data['status'] == 'Present'
                              ? Colors.green
                              : Colors.red;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 20,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withOpacity(0.12),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    data['date'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF0C0E11),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    data['day'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    data['status'],
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    data['inTime'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    data['outTime'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    data['hours'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showLeaveTypeDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A2313),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Leave',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 70 + MediaQuery.of(context).padding.bottom,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF3A2313),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    label: 'Home',
                    icon: Icons.home,
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  _NavItem(
                    label: 'Activity',
                    icon: Icons.access_time,
                    selected: true,
                    onTap: () {},
                  ),
                  _NavItem(
                    label: 'Settings',
                    icon: Icons.settings,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? const Color(0xFFC2BBB6) : Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: selected ? const Color(0xFFC2BBB6) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveTypeButton extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _LeaveTypeButton({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
