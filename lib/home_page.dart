import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'signin_page.dart';
import 'activity_page.dart';
import 'settings_page.dart';
import 'user_data_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String baseUrl = 'https://fondify.ai/api';

  String? _token;
  String? _userEmail;
  bool _isTokenLoaded = false;
  bool _isCheckingIn = false;
  bool _isCheckingOut = false;
  final GlobalKey<State> _homeKey = GlobalKey();

  // Mock data storage
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  List<Map<String, dynamic>> _mockActivity = [];
  bool _hasCheckedInToday = false;
  bool _hasCheckedOutToday = false;

  // Global key to trigger time details updates
  final GlobalKey<_TimeDetailsState> _timeDetailsKey =
      GlobalKey<_TimeDetailsState>();

  // Past mock activity data
  final List<Map<String, dynamic>> _pastMockActivity = [
    {
      'type': 'out',
      'date': '26/06/2025',
      'time': '06:30 PM',
      'status': 'Completed',
    },
    {'type': 'in', 'date': '26/06/2025', 'time': '09:15 AM', 'status': 'Late'},
    {
      'type': 'out',
      'date': '25/06/2025',
      'time': '05:45 PM',
      'status': 'Early Leave',
    },
    {
      'type': 'in',
      'date': '25/06/2025',
      'time': '08:55 AM',
      'status': 'On Time',
    },
    {
      'type': 'out',
      'date': '24/06/2025',
      'time': '06:00 PM',
      'status': 'Completed',
    },
    {'type': 'in', 'date': '24/06/2025', 'time': '09:30 AM', 'status': 'Late'},
  ];

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    if (_token != null) {
      // Load profile to get email
      Map<String, dynamic> profile;
      if (_token == 'dev_mock_token_for_ui_testing') {
        profile = await UserDataManager.instance.getProfile();
      } else {
        final response = await http.get(
          Uri.parse('$baseUrl/auth/profile/'),
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (response.statusCode == 200) {
          profile = jsonDecode(response.body);
        } else {
          profile = {};
        }
      }
      _userEmail = profile['email'] ?? 'unknown';
    } else {
      _userEmail = 'unknown';
    }
    setState(() {
      _isTokenLoaded = true;
    });
  }

  Future<void> _saveCurrentActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final activityJson = jsonEncode(_mockActivity);
    final userKey = _userEmail ?? 'unknown';
    await prefs.setString('current_activity_$userKey', activityJson);
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
  }

  Future<void> _saveTodayStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.day}-${today.month}-${today.year}';
    final userKey = _userEmail ?? 'unknown';
    await prefs.setBool('checkedIn_${userKey}_$todayKey', _hasCheckedInToday);
    await prefs.setBool('checkedOut_${userKey}_$todayKey', _hasCheckedOutToday);
    if (_checkInTime != null) {
      await prefs.setString(
        'checkInTime_${userKey}_$todayKey',
        _checkInTime!.toIso8601String(),
      );
    }
    if (_checkOutTime != null) {
      await prefs.setString(
        'checkOutTime_${userKey}_$todayKey',
        _checkOutTime!.toIso8601String(),
      );
    }
  }

  Future<void> _handleAuthError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');

    // Reset check-in/out status when logging out
    setState(() {
      _hasCheckedInToday = false;
      _hasCheckedOutToday = false;
      _checkInTime = null;
      _checkOutTime = null;
      _mockActivity.clear();
    });

    if (mounted) {
      // Import signin_page.dart at the top and navigate to it
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
    }
  }

  Future<Map<String, dynamic>> fetchProfile(String token) async {
    // Return cached profile data for development token
    if (token == 'dev_mock_token_for_ui_testing') {
      return await UserDataManager.instance.getProfile();
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('Profile response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body);
        // Cache the profile data
        await UserDataManager.instance.updateProfile(profileData);
        return profileData;
      } else if (response.statusCode == 401) {
        await _handleAuthError();
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Profile fetch error: $e');
      if (e.toString().contains('Authentication failed')) {
        rethrow;
      }
      throw Exception('Network error while fetching profile');
    }
  }

  Future<Map<String, dynamic>> fetchAttendance(String token) async {
    // Return mock data for development token
    if (token == 'dev_mock_token_for_ui_testing') {
      final now = DateTime.now();

      String checkInDisplay = '--:--';
      String checkOutDisplay = '--:--';
      String workingHours = '0.00h';

      if (_checkInTime != null) {
        checkInDisplay = _formatTimeAMPM(_checkInTime!);

        if (_checkOutTime != null) {
          checkOutDisplay = _formatTimeAMPM(_checkOutTime!);
          final duration = _checkOutTime!.difference(_checkInTime!);
          final totalMinutes = duration.inMinutes;
          final decimalHours = (totalMinutes / 60);
          workingHours = '${decimalHours.toStringAsFixed(2)}h';
        } else {
          // Calculate current working hours if checked in but not out
          final duration = now.difference(_checkInTime!);
          final totalMinutes = duration.inMinutes;
          final decimalHours = (totalMinutes / 60);
          workingHours = '${decimalHours.toStringAsFixed(2)}h';
        }
      }

      // Combine current activity with past mock data
      final combinedActivity = [..._mockActivity, ..._pastMockActivity];

      return {
        'check_in_time': checkInDisplay,
        'check_out_time': checkOutDisplay,
        'working_hours': workingHours,
        'date': '${now.day}/${now.month}/${now.year}',
        'activity': combinedActivity,
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/attendance/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('Attendance response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        await _handleAuthError();
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception('Failed to load attendance: ${response.statusCode}');
      }
    } catch (e) {
      print('Attendance fetch error: $e');
      if (e.toString().contains('Authentication failed')) {
        rethrow;
      }
      throw Exception('Network error while fetching attendance');
    }
  }

  String _formatTimeAMPM(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    // Convert to 12-hour format
    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showAttendanceSuccessDialog(
    String title,
    String message,
    bool isCheckIn,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Color(0xFF222831),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A2313),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
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

  Future<void> _refreshData() async {
    setState(() {});
  }

  Future<void> _checkIn() async {
    if (_token == null) return;

    setState(() {
      _isCheckingIn = true;
    });

    try {
      // Handle development token
      if (_token == 'dev_mock_token_for_ui_testing') {
        await Future.delayed(const Duration(seconds: 1)); // Simulate API delay

        if (_hasCheckedInToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already checked in today!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final now = DateTime.now();
        setState(() {
          _checkInTime = now;
          _checkOutTime = null;
          _hasCheckedInToday = true;
          _hasCheckedOutToday = false; // Reset checkout for new check-in
          _mockActivity.insert(0, {
            'type': 'in',
            'date': '${now.day}/${now.month}/${now.year}',
            'time': _formatTimeAMPM(now),
            'status': 'On Time',
            'datetime': now.toIso8601String(),
          });
        });

        // Save current activity and status to SharedPreferences
        await _saveCurrentActivity();
        await _saveTodayStatus();

        // Update time details display
        _timeDetailsKey.currentState?.updateTimes();

        // Show success dialog
        _showAttendanceSuccessDialog(
          'Attendance Successful!',
          'Great job! Your attendance has been successfully recorded. You\'re all set for today.',
          true,
        );
        await _refreshData();
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/employees/check-in/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'check_in_time': DateTime.now().toIso8601String()}),
      );

      print('Check-in response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully checked in!'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshData();
      } else if (response.statusCode == 401) {
        await _handleAuthError();
        return;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? 'Check-in failed');
      }
    } catch (e) {
      print('Check-in error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCheckingIn = false;
      });
    }
  }

  Future<void> _checkOut() async {
    if (_token == null) return;

    setState(() {
      _isCheckingOut = true;
    });

    try {
      // Handle development token
      if (_token == 'dev_mock_token_for_ui_testing') {
        await Future.delayed(const Duration(seconds: 1)); // Simulate API delay

        if (!_hasCheckedInToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please check in first!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        if (_hasCheckedOutToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already checked out today!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final now = DateTime.now();
        setState(() {
          _checkOutTime = now;
          _hasCheckedOutToday = true;
          _mockActivity.insert(0, {
            'type': 'out',
            'date': '${now.day}/${now.month}/${now.year}',
            'time': _formatTimeAMPM(now),
            'status': 'Completed',
            'datetime': now.toIso8601String(),
          });
        });

        // Save current activity and status to SharedPreferences
        await _saveCurrentActivity();
        await _saveTodayStatus();

        // Update time details display
        _timeDetailsKey.currentState?.updateTimes();

        final duration = now.difference(_checkInTime!);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;

        // Show success dialog
        _showAttendanceSuccessDialog(
          'Check-out Successful!',
          'You have successfully checked out at ${_formatTimeAMPM(now)}. Total work time: ${hours}h ${minutes}m. Have a great day!',
          false,
        );
        await _refreshData();
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/employees/check-out/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'check_out_time': DateTime.now().toIso8601String()}),
      );

      print('Check-out response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully checked out!'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshData();
      } else if (response.statusCode == 401) {
        await _handleAuthError();
        return;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? 'Check-out failed');
      }
    } catch (e) {
      print('Check-out error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-out failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCheckingOut = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) {
      // Load today's status after token is loaded
      _loadTodayStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double topSectionHeight = MediaQuery.of(context).size.height * 0.45;
    return Scaffold(
      backgroundColor: const Color(0xFFEBE9E7),
      body: !_isTokenLoaded
          ? const Center(child: CircularProgressIndicator())
          : _token == null
          ? const Center(child: Text('No authentication token found'))
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: FutureBuilder<Map<String, dynamic>>(
                key: _homeKey,
                future:
                    Future.wait([
                      fetchProfile(_token!),
                      fetchAttendance(_token!),
                    ]).then(
                      (results) => {
                        'profile': results[0],
                        'attendance': results[1],
                      },
                    ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final profile = snapshot.data!['profile'];
                  final attendance = snapshot.data!['attendance'];

                  // Profile fields
                  final String userName = profile['name'] ?? '-';
                  final String userRole = profile['role'] ?? '-';
                  final String userEmail = profile['email'] ?? '-';
                  final String userPhone = profile['phone'] ?? '-';
                  final String userImage = profile['image'] ?? '';

                  // Attendance fields (example structure, adjust as per your API)
                  final String checkInTime =
                      attendance['check_in_time'] ?? '--:--';
                  final String checkOutTime =
                      attendance['check_out_time'] ?? '--:--';
                  final String workingHours =
                      attendance['working_hours'] ?? '--h--m';
                  final String today = attendance['date'] ?? '-';
                  final List<dynamic> activity = attendance['activity'] ?? [];

                  return Scaffold(
                    body: Column(
                      children: [
                        // Top section with background image
                        SizedBox(
                          height: topSectionHeight,
                          child: Stack(
                            children: [
                              Container(
                                height: topSectionHeight,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      'assets/home_background.png',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Container(
                                height: topSectionHeight,
                                width: double.infinity,
                                color: Colors.black.withOpacity(0.45),
                              ),
                              SafeArea(
                                child: SizedBox(
                                  height: topSectionHeight,
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 24),
                                      // Profile Row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24.0,
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ProfilePage(
                                                          profile: profile,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: CircleAvatar(
                                                radius: 24,
                                                backgroundImage:
                                                    userImage.isNotEmpty
                                                    ? NetworkImage(userImage)
                                                    : const AssetImage(
                                                            'assets/WelcomeScreen.png',
                                                          )
                                                          as ImageProvider,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  userRole,
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 14,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Real-time Clock and Date
                                      const _RealTimeClock(),
                                      const SizedBox(height: 24),
                                      // Check In/Out Buttons
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: _ClockButton(
                                                label: _isCheckingIn
                                                    ? 'Checking In...'
                                                    : _hasCheckedInToday
                                                    ? 'Checked In'
                                                    : 'Check In',
                                                icon: _isCheckingIn
                                                    ? Icons.hourglass_empty
                                                    : _hasCheckedInToday
                                                    ? Icons.check_circle
                                                    : Icons.touch_app,
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF3A2313),
                                                    Color(0xFF3A2313),
                                                  ],
                                                ),
                                                onTap:
                                                    (_isCheckingIn ||
                                                        _hasCheckedInToday)
                                                    ? null
                                                    : _checkIn,
                                                isDisabled: _hasCheckedInToday,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: _ClockButton(
                                                label: _isCheckingOut
                                                    ? 'Checking Out...'
                                                    : _hasCheckedOutToday
                                                    ? 'Checked Out'
                                                    : !_hasCheckedInToday
                                                    ? 'Check In First'
                                                    : 'Check Out',
                                                icon: _isCheckingOut
                                                    ? Icons.hourglass_empty
                                                    : _hasCheckedOutToday
                                                    ? Icons.check_circle
                                                    : !_hasCheckedInToday
                                                    ? Icons.block
                                                    : Icons.touch_app,
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF3A2313),
                                                    Color(0xFF3A2313),
                                                  ],
                                                ),
                                                onTap:
                                                    (_isCheckingOut ||
                                                        _hasCheckedOutToday ||
                                                        !_hasCheckedInToday)
                                                    ? null
                                                    : _checkOut,
                                                isDisabled:
                                                    _hasCheckedOutToday ||
                                                    !_hasCheckedInToday,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Time Details
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24.0,
                                        ),
                                        child: _TimeDetails(
                                          key: _timeDetailsKey,
                                          checkInTime: _checkInTime,
                                          checkOutTime: _checkOutTime,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bottom section (activity)
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                // Your Activity
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Your Activity',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                          color: Color(0xFF0C0E11),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ActivityPage(),
                                            ),
                                          );
                                          // Refresh home page data when returning from activity page
                                          _refreshData();
                                        },
                                        child: const Text(
                                          'View all',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                            color: Color(0xFF0C0E11),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Activity Cards (Clock-In/Out)
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                      ),
                                      child: Column(
                                        children: activity.isNotEmpty
                                            ? activity.take(3).map<Widget>((
                                                item,
                                              ) {
                                                return _ActivityCard(
                                                  icon: item['type'] == 'in'
                                                      ? Icons.login
                                                      : Icons.logout,
                                                  label: item['type'] == 'in'
                                                      ? 'Clock-In'
                                                      : 'Clock-Out',
                                                  date: item['date'] ?? '-',
                                                  time: item['time'] ?? '-',
                                                  status: item['status'] ?? '-',
                                                );
                                              }).toList()
                                            : [const Text('No activity yet')],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    bottomNavigationBar: Container(
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
                              selected: true,
                              onTap: () {
                                // Already on home page
                              },
                            ),
                            _NavItem(
                              label: 'Activity',
                              icon: Icons.access_time,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ActivityPage(),
                                  ),
                                );
                                // Refresh home page data when returning from activity page
                                _refreshData();
                              },
                            ),
                            _NavItem(
                              label: 'Settings',
                              icon: Icons.settings,
                              onTap: () {
                                Navigator.of(context).push(
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
                  );
                },
              ),
            ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String baseUrl = 'https://fondify.ai/api';
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['name'] ?? '');
    _phoneController = TextEditingController(
      text: widget.profile['phone'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Handle development token with mock update
      if (token == 'dev_mock_token_for_ui_testing') {
        await Future.delayed(const Duration(seconds: 1)); // Simulate API delay

        // Update the profile data in UserDataManager
        await UserDataManager.instance.updateField(
          'name',
          _nameController.text.trim(),
        );
        await UserDataManager.instance.updateField(
          'phone',
          _phoneController.text.trim(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully! (Demo Mode)'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
          widget.profile['name'] = _nameController.text.trim();
          widget.profile['phone'] = _phoneController.text.trim();
        });
        return;
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      print('Profile update response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
          widget.profile['name'] = _nameController.text.trim();
          widget.profile['phone'] = _phoneController.text.trim();
        });
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? 'Profile update failed');
      }
    } catch (e) {
      print('Profile update error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile update failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF3A2313),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit),
            ),
          if (_isEditing && !_isLoading)
            TextButton(
              onPressed: _updateProfile,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          if (_isEditing && !_isLoading)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = widget.profile['name'] ?? '';
                  _phoneController.text = widget.profile['phone'] ?? '';
                });
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: (widget.profile['image'] ?? '').isNotEmpty
                        ? NetworkImage(widget.profile['image'])
                        : const AssetImage('assets/WelcomeScreen.png')
                              as ImageProvider,
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing) ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ] else ...[
                    Text(
                      widget.profile['name'] ?? '-',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    widget.profile['role'] ?? '-',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(widget.profile['email'] ?? '-'),
                  ),
                  if (_isEditing) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone'),
                      subtitle: Text(widget.profile['phone'] ?? '-'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ClockButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  final bool isDisabled;

  const _ClockButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isButtonDisabled = onTap == null || isDisabled;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: isButtonDisabled
            ? LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade400],
              )
            : gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isButtonDisabled
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isButtonDisabled ? null : onTap,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeDetail extends StatelessWidget {
  final IconData icon;
  final String time;
  final String label;
  final Color color;

  const _TimeDetail({
    required this.icon,
    required this.time,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 11,
            color: color.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final String time;
  final String status;

  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.date,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Determine icon color based on check-in or check-out
    final bool isCheckIn = icon == Icons.login;
    final Color iconColor = isCheckIn
        ? const Color.fromARGB(255, 255, 105, 60)
        : const Color.fromARGB(183, 244, 67, 54);
    final Color iconBgColor = isCheckIn
        ? const Color.fromARGB(255, 231, 158, 97).withOpacity(0.15)
        : const Color.fromARGB(255, 255, 0, 0).withOpacity(0.15);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconBgColor,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF222831),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: Color(0xFFBABCBF),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF222831),
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: Color(0xFFBABCBF),
                ),
              ),
            ],
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
          Icon(icon, color: selected ? Color(0xFFC2BBB6) : Colors.white),
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

// Separate widget for real-time clock to prevent main page rebuilds
class _RealTimeClock extends StatefulWidget {
  const _RealTimeClock();

  @override
  State<_RealTimeClock> createState() => _RealTimeClockState();
}

class _RealTimeClockState extends State<_RealTimeClock> {
  Timer? _clockTimer;
  String _currentTime = '';
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final newTime = _formatTimeAMPM(now);
    final newDate =
        '${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}, ${now.year}';

    // Only update if time or date actually changed
    if (newTime != _currentTime || newDate != _currentDate) {
      if (mounted) {
        setState(() {
          _currentTime = newTime;
          _currentDate = newDate;
        });
      }
    }
  }

  String _formatTimeAMPM(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _currentTime.isNotEmpty ? _currentTime : '--:--',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currentDate.isNotEmpty ? _currentDate : 'Loading...',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Separate widget for time details that updates in real-time
class _TimeDetails extends StatefulWidget {
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  const _TimeDetails({super.key, this.checkInTime, this.checkOutTime});

  @override
  State<_TimeDetails> createState() => _TimeDetailsState();
}

class _TimeDetailsState extends State<_TimeDetails> {
  Timer? _updateTimer;
  String _checkInDisplay = '--:--';
  String _checkOutDisplay = '--:--';
  String _workingHours = '0h 0m';

  @override
  void initState() {
    super.initState();
    updateTimes();
    // Update working hours every minute if checked in but not out
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (widget.checkInTime != null && widget.checkOutTime == null) {
        updateTimes();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void updateTimes() {
    if (mounted) {
      setState(() {
        if (widget.checkInTime != null) {
          _checkInDisplay = _formatTimeAMPM(widget.checkInTime!);

          if (widget.checkOutTime != null) {
            _checkOutDisplay = _formatTimeAMPM(widget.checkOutTime!);
            final duration = widget.checkOutTime!.difference(
              widget.checkInTime!,
            );
            final totalMinutes = duration.inMinutes;
            final decimalHours = (totalMinutes / 60);
            _workingHours = '${decimalHours.toStringAsFixed(2)}h';
          } else {
            _checkOutDisplay = '--:--';
            // Calculate current working hours if checked in but not out
            final now = DateTime.now();
            final duration = now.difference(widget.checkInTime!);
            final totalMinutes = duration.inMinutes;
            final decimalHours = (totalMinutes / 60);
            _workingHours = '${decimalHours.toStringAsFixed(2)}h';
          }
        } else {
          _checkInDisplay = '--:--';
          _checkOutDisplay = '--:--';
          _workingHours = '0.00h';
        }
      });
    }
  }

  String _formatTimeAMPM(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TimeDetail(
          icon: Icons.access_time,
          time: _checkInDisplay,
          label: 'Check In',
          color: Colors.white,
        ),
        _TimeDetail(
          icon: Icons.access_time,
          time: _checkOutDisplay,
          label: 'Check Out',
          color: Colors.white,
        ),
        _TimeDetail(
          icon: Icons.timer,
          time: _workingHours,
          label: 'Working Hrs',
          color: Colors.white,
        ),
      ],
    );
  }
}
