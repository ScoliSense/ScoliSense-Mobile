import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;

import 'NotificationPage.dart';
import 'ProfilePage.dart';
import 'Help.dart';
import 'login_page.dart';
import 'ScanDevicesPage.dart';
import 'EnterCodePage.dart';
import 'bluetooth_service.dart' as my_ble;
import 'notification_service.dart';

class MainPage extends StatefulWidget {
  final bool forceBadgeRefresh;
  MainPage({this.forceBadgeRefresh = false});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  String _connectionStatus = "Not Connected";
  List<String> _devices = [];
  BluetoothDevice? _connectedDevice;

  PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> _latestMessages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  final int maxMessages = 10;
  int _animatedListLength = 0;

  double _daysWorn = 0;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🔥 Added

    _loadStoredDevices();
    _fetchBraceUsageDays();

    if (widget.forceBadgeRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.forceNotifyUnreadCount();
        print('[MainPage] forceNotifyUnreadCount called post-frame');
      });
    }

    _statusSubscription = my_ble.MyBluetoothService().statusStream.listen((entry) {
      if (!mounted || _listKey.currentState == null) return;

      if (_latestMessages.length >= maxMessages) {
        final removed = _latestMessages.removeAt(0);
        _animatedListLength--;
        _listKey.currentState!.removeItem(
          0,
              (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: _buildLiveMessage(removed),
          ),
          duration: Duration(milliseconds: 300),
        );
      }

      _latestMessages.add(entry);
      int insertIndex = _latestMessages.length - 1;

      if (insertIndex >= 0 && insertIndex <= _animatedListLength) {
        _listKey.currentState!.insertItem(
          insertIndex,
          duration: Duration(milliseconds: 300),
        );
        _animatedListLength++;

        Future.delayed(Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🔥 Added
    _statusSubscription?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🔥 NEW: Handle resume from background to refresh unread count
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.forceNotifyUnreadCount();
      print("[MainPage] App resumed, force-refreshing badge count.");
    }
  }

  Future<void> _fetchBraceUsageDays() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('deviceId');

    if (deviceId != null && deviceId.isNotEmpty) {
      final url = Uri.parse(
        'https://scolisensemvpserver-azhpd3hchqgsc8bm.germanywestcentral-01.azurewebsites.net/api/Device/usage/$deviceId',
      );
      String? token = prefs.getString('authToken');

      try {
        final response = await http.get(
          url,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          double hours = (data['hours'] ?? 0.0).toDouble();
          double days = hours / 12.0;

          if (mounted) {
            setState(() {
              _daysWorn = days > 0 ? days : 0;
            });
          }
        } else {
          if (mounted) setState(() => _daysWorn = 0);
        }
      } catch (e) {
        if (mounted) setState(() => _daysWorn = 0);
      }
    } else {
      if (mounted) setState(() => _daysWorn = 0);
    }
  }

  Future<void> _loadStoredDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? roleSpecificDataString = prefs.getString('roleSpecificData');

    if (roleSpecificDataString != null) {
      try {
        final roleSpecificData = jsonDecode(roleSpecificDataString);
        List<dynamic> deviceList = roleSpecificData['devices'] ?? [];

        if (mounted) {
          setState(() {
            _devices = deviceList.map<String>((device) =>
            (device is Map && device.containsKey('name')) ? device['name'].toString() : 'Unknown Device').toList();
          });
        }
      } catch (e) {
        if (mounted) setState(() => _devices = []);
      }
    } else {
      if (mounted) setState(() => _devices = []);
    }
  }

  void _updateConnectionStatus(String deviceName) {
    if (!mounted) return;
    setState(() {
      _connectionStatus = (deviceName == "Not Connected" || deviceName.isEmpty)
          ? "Not Connected"
          : "Connected to $deviceName";
    });
  }

  void _checkAndNavigate(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isPaired = prefs.getBool('isPaired') ?? false;

    if (!mounted) return;

    if (isPaired) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScanDevicesPage(
            onDeviceConnected: _updateConnectionStatus,
          ),
        ),
      );

      if (result != null && result is String && mounted) {
        _updateConnectionStatus(result);
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EnterCodePage()),
      );
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.blueGrey.shade900,
                    Colors.blueGrey.shade800,
                  ],
                ),
              ),
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentPage = index;
                    });
                  }
                },
                children: [
                  _buildGaugePage(),
                  _buildLiveDataPage(),
                  _buildBraceUsageGraphPage(),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: _buildConnectionButton(context),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 5,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset('assets/scoli_logo.png', height: 100),
      ),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: NotificationService.unreadCountNotifier,
          builder: (context, unreadCount, child) {
            return badges.Badge(
              position: badges.BadgePosition.topEnd(top: 8, end: 8),
              badgeContent: Text(
                unreadCount.toString(),
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
              showBadge: unreadCount > 0,
              badgeStyle: badges.BadgeStyle(
                badgeColor: Colors.redAccent,
              ),
              child: IconButton(
                icon: Icon(Icons.notifications, color: Colors.cyanAccent),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationPage()));
                },
              ),
            );
          },
        ),
        _buildSettingsDropdown(context),
      ],
    );
  }

  // Keep the _buildGaugePage structure from the new code
  Widget _buildGaugePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Call the REVERTED gauge builder below
          _buildFullCircleGauge(),
          SizedBox(height: 15),
          Text("Congratulations!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          SizedBox(height: 5),
          Text("You have worn the scoliosis brace for ${_daysWorn.toStringAsFixed(0)} days.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white70)),
          SizedBox(height: 30),
          // Keep the page indicator from the new code
          _buildPageIndicator(),
          // Keep the SizedBox for spacing from the new code
          SizedBox(height: 80),
        ],
      ),
    );
  }

  // Keep the _buildLiveDataPage from the new code
  Widget _buildLiveDataPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors, size: 80, color: Colors.cyanAccent),
          SizedBox(height: 20),
          Text("Live Sensor Data",
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Container(
            height: 200,
            width: 320,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                )
              ],
            ),
            child: AnimatedList(
              key: _listKey,
              controller: _scrollController,
              initialItemCount: _animatedListLength,
              itemBuilder: (context, index, animation) {
                if (index >= 0 && index < _latestMessages.length) {
                  return SizeTransition(
                    sizeFactor: animation,
                    child: _buildLiveMessage(_latestMessages[index]), // Uses new code message style
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildLegend("✅", "Sent"), // Keep legend
                _buildLegend("📦", "Stored"),
                _buildLegend("❌", "Error"),
              ],
            ),
          ),
          SizedBox(height: 30),
          // Keep the page indicator from the new code
          _buildPageIndicator(),
          // Keep the SizedBox for spacing from the new code
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBraceUsageGraphPage() {
    return Column(
      children: [
        Expanded(child: BraceUsageGraphPage()),
        SizedBox(height: 100), // 👈 bring page dots closer to graph
        _buildPageIndicator(),
        SizedBox(height: 100), // 👈 optional bottom spacing
      ],
    );
  }


  // Keep the legend builder from the new code
  Widget _buildLegend(String emoji, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: 18)),
        SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  // Keep the live message builder from the new code
  Widget _buildLiveMessage(Map<String, String> entry) {
    String emoji = entry["status"] == "success"
        ? "✅"
        : entry["status"] == "stored"
        ? "📦"
        : "❌";
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        "${entry["msg"] ?? 'No message'} $emoji", // Keep null check
        style: TextStyle( // Keep new code styling
          fontSize: 16,
          color: Colors.cyanAccent.withOpacity(0.9),
        ),
      ),
    );
  }

  // --- REVERTED GAUGE IMPLEMENTATION ---
  // This method's body is replaced with the old code version.
  Widget _buildFullCircleGauge() {
    return SizedBox(
      height: 250,
      width: 250,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: 365, // Old maximum
            startAngle: 270,
            endAngle: 270,
            showLabels: false,
            showTicks: false,
            axisLineStyle: AxisLineStyle(
              thickness: 15,
              color: Colors.grey.shade400, // Old background color
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: _daysWorn, // Use _daysWorn directly
                width: 15,
                color: Colors.cyanAccent,
                enableAnimation: true,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Text(
                  _daysWorn.toStringAsFixed(0), // Display rounded days
                  style: TextStyle(
                      fontSize: 40, // Old font size
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                positionFactor: 0.0,
                angle: 90,
              ),
            ],
          ),
        ],
      ),
    );
  }
  // --- END OF REVERTED GAUGE IMPLEMENTATION ---

  // Keep the connection button from the new code
  Widget _buildConnectionButton(BuildContext context) {
    return TextButton(
      onPressed: () => _checkAndNavigate(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        _connectionStatus,
        style: TextStyle( // Keep new code style (no underline)
          color: Colors.cyanAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Keep the settings dropdown from the new code (with improved dialog handling)
  Widget _buildSettingsDropdown(BuildContext context) {
    bool isMounted() => context.mounted;

    return PopupMenuButton<String>(
      icon: Icon(Icons.settings, color: Colors.cyanAccent),
      color: Colors.blueGrey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 8.0,
      onSelected: (value) async {
        if (value == "Profile") {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => ProfilePage()));
        } else if (value == "Help") {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => HelpPage()));
        } else if (value == "Logout") {
          final confirm = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                backgroundColor: Colors.blueGrey.shade800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                title: Text("Confirm Logout", style: TextStyle(color: Colors.white)),
                content: Text("Are you sure you want to log out?",
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    child: Text("Cancel", style: TextStyle(color: Colors.cyanAccent)),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  TextButton(
                    child: Text("Logout", style: TextStyle(color: Colors.redAccent)),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              );
            },
          );

          if (!isMounted()) return;

          if (confirm == true) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            if (!isMounted()) return;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
            );
          }
        }
      },
      itemBuilder: (BuildContext context) {
        // Keep new code menu item structure
        return [
          PopupMenuItem<String>(
            value: "Profile",
            child: Row(
              children: [
                Icon(Icons.person_outline, color: Colors.cyanAccent.withOpacity(0.8), size: 20),
                SizedBox(width: 10),
                Text("Profile", style: TextStyle(color: Colors.cyanAccent)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: "Help",
            child: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.cyanAccent.withOpacity(0.8), size: 20),
                SizedBox(width: 10),
                Text("Help", style: TextStyle(color: Colors.cyanAccent)),
              ],
            ),
          ),
          PopupMenuDivider(
            height: 1.0,
          ),
          PopupMenuItem<String>(
            value: "Logout",
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.redAccent.withOpacity(0.8), size: 20),
                SizedBox(width: 10),
                Text("Logout", style: TextStyle(color: Colors.redAccent.withOpacity(0.9))),
              ],
            ),
          ),
        ];
      },
    );
  }

  // Keep the page indicator from the new code
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        bool isActive = index == _currentPage;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 5),
          height: isActive ? 10 : 8,
          width: isActive ? 10 : 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.cyanAccent : Colors.white30,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.5),
                blurRadius: 4.0,
              )
            ]
                : [],
          ),
        );
      }),
    );
  }
} // End of _MainPageState

// --- REVERTED: Use the BraceUsageGraphPage class from the OLD CODE ---
// The entire implementation below is from the "old code" snippet provided.
// Full BraceUsageGraphPage with fixed layout and scroll handling
class BraceUsageGraphPage extends StatefulWidget {
  @override
  _BraceUsageGraphPageState createState() => _BraceUsageGraphPageState();
}

class _BraceUsageGraphPageState extends State<BraceUsageGraphPage> {
  List<Map<String, dynamic>> _usageData = [];
  bool _isLoading = false;

  bool _isWeekView = true;
  int _viewOffset = 0;
  int? _selectedBarIndex;

  DateTime? _latestAvailableDate;

  @override
  void initState() {
    super.initState();
    _fetchUsageData();
  }

  Future<void> _fetchUsageData() async {
    setState(() => _isLoading = true);
    final uri = Uri.parse(
        'https://scolisensemvpserver-azhpd3hchqgsc8bm.germanywestcentral-01.azurewebsites.net/api/User/brace-usage');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        print("No token found");
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        List<dynamic> result = json.decode(response.body);
        List<Map<String, dynamic>> newData = result
            .map<Map<String, dynamic>>((e) => {
          "date": DateTime.parse(e['date']),
          "minutes": e['minutesUsed']
        })
            .toList();

        newData.sort((a, b) => a["date"].compareTo(b["date"]));

        setState(() {
          _usageData = newData;
          _latestAvailableDate = _usageData.last['date'];
          _isLoading = false;
        });
      } else {
        print("Failed to fetch usage data: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error during usage fetch: $e");
      setState(() => _isLoading = false);
    }
  }

  void _changeOffset(int delta) {
    setState(() {
      _viewOffset += delta;
    });
  }

  List<Map<String, dynamic>> _getDisplayedData() {
    if (_usageData.isEmpty) return [];

    DateTime end;
    DateTime start;

    if (_isWeekView) {
      DateTime base = _latestAvailableDate ?? DateTime.now();
      base = base.subtract(Duration(days: base.weekday - 1));
      start = base.add(Duration(days: 7 * _viewOffset));
      end = start.add(Duration(days: 6));
    } else {
      DateTime base = _latestAvailableDate ?? DateTime.now();
      DateTime monthStart = DateTime(base.year, base.month, 1);
      start = DateTime(monthStart.year, monthStart.month + _viewOffset, 1);
      end = DateTime(start.year, start.month + 1, 0);
    }

    final filtered = _usageData.where((entry) {
      return entry['date'].isAfter(start.subtract(Duration(days: 1))) &&
          entry['date'].isBefore(end.add(Duration(days: 1)));
    }).toList();

    if (_isWeekView) {
      return List.generate(7, (i) {
        final d = start.add(Duration(days: i));
        final existing = filtered.firstWhere(
                (e) => _sameDate(e['date'], d),
            orElse: () => {"date": d, "minutes": 0});
        return existing;
      });
    } else {
      int daysInMonth = end.day;
      return List.generate(daysInMonth, (i) {
        final d = DateTime(start.year, start.month, i + 1);
        final existing = filtered.firstWhere(
                (e) => _sameDate(e['date'], d),
            orElse: () => {"date": d, "minutes": 0});
        return existing;
      });
    }
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final displayData = _getDisplayedData();

    if (displayData.isEmpty) {
      return Center(
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.cyanAccent)
            : Text(
          "No data available",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final maxEntry = displayData.reduce((a, b) =>
    (a['minutes'] as num) > (b['minutes'] as num) ? a : b);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isWeekView
                      ? "Week of ${DateFormat('yMMMd').format(displayData.first['date'])}"
                      : DateFormat('MMMM yyyy')
                      .format(displayData.first['date']),
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => setState(() => _isWeekView = !_isWeekView),
                  child: Text(
                    _isWeekView ? "Month View" : "Week View",
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                )
              ],
            ),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Brace Usage Duration",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600)),
                          SizedBox(height: 4),
                          Text(
                            "${(displayData.map((e) => e['minutes']).reduce((a, b) => a + b) ~/ 60)}h ${(displayData.map((e) => e['minutes']).reduce((a, b) => a + b) % 60)}m",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ],
                      ),
                      Container(
                        padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _isWeekView ? "Week" : "Month",
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! < 0) {
                          _changeOffset(-1);
                        } else if (details.primaryVelocity! > 0) {
                          _changeOffset(1);
                        }
                      }
                    },
                    child: SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("8 hr",
                                  style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                              Text("4 hr",
                                  style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                              Text("1 hr",
                                  style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: _isWeekView
                                      ? Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                    children: displayData
                                        .asMap()
                                        .entries
                                        .map((entry) =>
                                        _buildBar(entry, maxEntry))
                                        .toList(),
                                  )
                                      : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                      children: displayData
                                          .asMap()
                                          .entries
                                          .map((entry) => _buildBar(
                                          entry, maxEntry))
                                          .toList(),
                                    ),
                                  ),
                                ),
                                Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                  height: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(MapEntry<int, Map<String, dynamic>> entry,
      Map<String, dynamic> maxEntry) {
    int index = entry.key;
    var data = entry.value;
    final isMax = data == maxEntry;
    final isSelected = _selectedBarIndex == index;

    final heightFactor =
    ((data['minutes'] as int) / (maxEntry['minutes'] as int).toDouble())
        .clamp(0.0, 1.0);
    final barColor = isSelected
        ? Colors.cyan
        : (isMax ? Colors.indigoAccent : Colors.indigo.shade100);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBarIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  "${(data['minutes'] ~/ 60)}h ${(data['minutes'] % 60)}m",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: 100 * heightFactor + 10,
              width: _isWeekView ? 28 : 18,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(color: Colors.cyanAccent, width: 2)
                    : null,
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.4),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ]
                    : [],
              ),
            ),
            SizedBox(height: 6),
            Text(
              _isWeekView
                  ? DateFormat('E').format(data['date'])[0]
                  : DateFormat('d').format(data['date']),
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}