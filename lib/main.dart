import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'SettingsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

List<String> buttonValues = ['W', 'w', 'X', 'x', 'v'];

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    return MaterialApp(
      home: Scaffold(
        body: UI(),
      ),
    );
  }
}

class UI extends StatefulWidget {
  @override
  _UIState createState() => _UIState();
}

Future<void> requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location, // 위치 액세스 권한 추가
  ].request();
}

// 권한 상태 체크
Future<bool> checkAndRequestPermissions(BuildContext context) async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
  ].request();

  if (statuses.values.any((status) => status != PermissionStatus.granted)) {
    // 권한 중 하나라도 거부된 경우
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('권한이 거부되었습니다. 앱 설정에서 블루투스, 위치 권한을 허용해주세요.'),
      ),
    );
    return false;
  }
  return true;
}

class _UIState extends State<UI> {
  Timer? _timer;
  bool _isToggleOn = false; // 토글 버튼 상태
  Map<String, String> sensorData = {}; // 시그널 이름에 따른 데이터를 저장할 맵
  List<bool> sensorVisibility = [
    true,
    true,
    true,
    true,
    true,
    true
  ]; // 각 시그널의 표시 여부를 저장하는 리스트
  List<String> sensorNames = ['소리', '빛', '거리', 'X축', 'Y축', 'Z축'];

  bool _isBluetoothButtonPressed = false;

  var manualbutton_isPressed = false;
  var youtubebutton_isPressed = false;

  double _lastLeftX = 0.0;
  double _lastLeftY = 0.0;
  double _lastRightX = 0.0;
  double _lastRightY = 0.0;

  String getLocalizedValue(String key) {
    Map<String, Map<String, String>> localizedValues = {
      'en': {
        'connected': 'Connected',
        'sensor': 'Sensor Value',
        'cancel': 'Cancel',
        'disconnect': 'Disconnect',
        'bluetoothConnect': 'Connected to',
        'bluetoothDisconnect': 'Disconnected from',
        'bluetoothFail': 'Failed to connect to',
        'selectDevice': 'Select Device',
        'manual': 'Manual',
        'sound': 'Sound',
        'light': 'Light',
        'distance': 'Dist',
        'xaxis': 'X-axis',
        'yaxis': 'Y-axis',
        'zaxis': 'Z-axis',
        'manualUri':
            'https://docs.google.com/document/d/1NYpY9ESDuNnLpAf_NwuDHWYGhlxvlmAOpOvIv5epY6E/edit?usp=sharing',
      },
      'ko': {
        'connected': '연결된 장치',
        'sensor': '센서 값',
        'cancel': '취소',
        'disconnect': '연결 끊기',
        'bluetoothConnect': '기기와 연결되었습니다.',
        'bluetoothDisconnect': '연결이 해제되었습니다.',
        'bluetoothFail': '연결에 실패했습니다.',
        'selectDevice': '장치 선택',
        'manual': '매뉴얼',
        'sound': '소리',
        'light': '빛',
        'distance': '거리',
        'xaxis': 'X축',
        'yaxis': 'Y축',
        'zaxis': 'Z축',
        'manualUri':
            'https://docs.google.com/document/d/1uCi4EoWiQw6Gm6p-sw184RyOPpzdr7lmGMAGYydvVOE/edit?usp=sharing',
      }
    };
    String langCode = Global.isKorean ? 'ko' : 'en';
    return localizedValues[langCode]![key]!;
  }

  void loadsensorNames(SharedPreferences prefs) async {
    sensorNames = [
      getLocalizedValue('sound'),
      getLocalizedValue('light'),
      getLocalizedValue('distance'),
      getLocalizedValue('xaxis'),
      getLocalizedValue('yaxis'),
      getLocalizedValue('zaxis')
    ];
    await prefs.setStringList('sensorNames', sensorNames);
  }

  void _showLanguagePicker(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text('English'),
                selected: !Global.isKorean,
                leading: !Global.isKorean ? Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    Global.isKorean = false;
                    saveLanguagePreference(Global.isKorean);
                    loadsensorNames(prefs);
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('한글'),
                selected: Global.isKorean,
                leading: Global.isKorean ? Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    Global.isKorean = true;
                    saveLanguagePreference(Global.isKorean);
                    loadsensorNames(prefs);
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> saveLanguagePreference(bool isKorean) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isKorean', isKorean);
  }

  Future<void> loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    Global.isKorean = prefs.getBool('isKorean') ?? true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    loadLanguagePreference();
    loadButtonValues();
    loadsensorVisibility().then((_) {
      // loadsensorVisibility가 완료되면 상태 업데이트
      if (mounted) {
        setState(() {});
      }
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    requestPermissions().then((_) {
      // _selectBluetoothConnection();
    });
  }

  // 링크 열기 함수 정의
  Future<void> _launchUrl(_url) async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<void> loadButtonValues() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? storedButtonValues = prefs.getStringList('buttonValues');
    if (storedButtonValues != null && storedButtonValues.isNotEmpty) {
      setState(() {
        buttonValues = storedButtonValues;
      });
    }
  }

  Widget buildButton(int index) {
    return CustomButton(
      index: index,
      onPressed: () => _sendMessage(buttonValues[index]),
    );
  }

  Future<void> loadsensorVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    // 비어 있는 경우 기본 값을 설정
    sensorNames = prefs.getStringList('sensorNames') ??
        ['소리', '빛', '거리', 'X축', 'Y축', 'Z축'];
    sensorVisibility = List.generate(sensorNames.length, (index) {
      return prefs.getBool('sensorCheck_$index') ?? true;
    });
    // 상태를 업데이트 하기 전에 항상 mounted를 확인
    if (mounted) {
      setState(() {});
    }
  }

  void _updatesensorData(List<String> values) async {
    loadsensorVisibility();
    Map<String, String> newsensorData = {};

    for (int i = 0; i < sensorNames.length; i++) {
      if (i < values.length) {
        String value = values[i].trim(); // 공백 제거
        if (value.isNotEmpty) {
          newsensorData[sensorNames[i]] = value;
        } else if (sensorData.containsKey(sensorNames[i])) {
          // 값이 비어 있으면 이전 값 유지 (이전 값이 있는 경우)
          newsensorData[sensorNames[i]] = sensorData[sensorNames[i]] ?? 'N/A';
        } else {
          // 이전 값도 없는 경우 'N/A' 설정
          newsensorData[sensorNames[i]] = 'N/A';
        }
      } else {
        // 설정된 신호 이름에 해당하는 값이 전송되지 않은 경우 'N/A'로 설정
        newsensorData[sensorNames[i]] = sensorData[sensorNames[i]] ?? 'N/A';
      }
    }

    setState(() {
      sensorData = newsensorData;
    });
  }

  void _toggleButton(bool newValue) {
    setState(() {
      _isToggleOn = newValue;
    });

    if (_isToggleOn) {
      // 토글이 켜지면 타이머 시작
      _timer = Timer.periodic(Duration(milliseconds: 100), (Timer t) {
        _sendMessage('O');
      });
    } else {
      // 토글이 꺼지면 타이머 중지하고 'o' 신호 전송
      _timer?.cancel();
      _sendMessage('o');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _connectedDeviceName = '';
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devicesList = [];

  void _sendMessage(String message) {
    if (_connection != null) {
      try {
        _connection!.output.add(utf8.encode(message + "\r\n"));
        _connection!.output.allSent.then((_) {
          // print('Sent: $message');
        });
      } catch (e) {
        // print('Error sending message: $e');
      }
    } else {
      // print('Bluetooth connection is not established.');
    }
  }

  Future<void> saveRecentDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recentDeviceName', device.name ?? "");
    await prefs.setString('recentDeviceAddress', device.address);
  }

  Future<BluetoothDevice?> loadRecentDevice() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('recentDeviceName');
    String? address = prefs.getString('recentDeviceAddress');
    if (name != null && address != null) {
      return BluetoothDevice(name: name, address: address);
    }
    return null;
  }

  void _showDeviceList() async {
    BluetoothDevice? recentDevice = await loadRecentDevice();
    List<BluetoothDevice> devices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    if (recentDevice != null) {
      devices.removeWhere((device) => device.address == recentDevice.address);
      devices.insert(0, recentDevice); // 최근 연결한 기기를 목록의 맨 위에 추가
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(getLocalizedValue('selectDevice')),
          content: Container(
            width: double.maxFinite,
            // height: 300, // 높이를 설정하여 스크롤 가능하게 만듬
            child: ShaderMask(
                shaderCallback: (Rect rect) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.7, 1.0], // 90%는 보이고, 마지막 10%에서 페이드아웃
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstOut, // 콘텐츠를 페이드아웃
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Column(
                      children: [
                        ListTile(
                          onTap: () {
                            _connectToDevice(devices[index]);
                            Navigator.of(context).pop();
                          },
                          title: Text(devices[index].name ?? "Unknown device"),
                          subtitle: Text(devices[index].address),
                          leading: index == 0 && recentDevice != null
                              ? Icon(Icons.history)
                              : null,
                        ),
                        Divider(), // 각 아이템 사이에 구분선 추가
                      ],
                    );
                  },
                )),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(getLocalizedValue('cancel')),
            ),
            TextButton(
              onPressed: () {
                _disconnectDevice();
                Navigator.of(context).pop();
              },
              child: Text(getLocalizedValue('disconnect')),
              style: TextButton.styleFrom(
                foregroundColor:
                    Colors.red, // Set the text color to red for emphasis
              ),
            ),
          ],
        );
      },
    );
  }

  void _disconnectDevice() async {
    if (_connection != null) {
      await _connection?.finish(); // 'finish' 메서드로 변경
      setState(() {
        _connection = null;
        _connectedDeviceName = '';
      });
      //print("Disconnected from all devices");
    }
  }

  void _selectBluetoothConnection() async {
    bool hasPermissions = await checkAndRequestPermissions(context);
    if (!hasPermissions) return;
    List<BluetoothDevice> devices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _devicesList = devices;
    });
    _showDeviceList(); // 기기 목록을 보여주는 다이얼로그 호출
  }

  void _connectToDevice(BluetoothDevice device) async {
    if (_connection != null) {
      await _connection?.finish();
      _connection = null;
    }

    try {
      var connection = await BluetoothConnection.toAddress(device.address);
      if (connection.isConnected) {
        setState(() {
          _connection = connection;
          _connectedDeviceName = device.name ?? "";
        });

        int count = 10;
        for (int i = 0; i < count; i++) {
          await Future.delayed(Duration(milliseconds: 100));
          try {
            _connection!.output.add(utf8.encode(""));
          } catch (e) {
            setState(() {
              _connectedDeviceName = '';
              _connection = null;
            });
            _showConnectionStatus(
                '${getLocalizedValue('bluetoothFail')} ${device.name}');
            return;
          }
        }
        saveRecentDevice(device);
        _showConnectionStatus(
            '${getLocalizedValue('bluetoothConnect')} ${device.name}');
        _connection?.input?.listen(_onDataReceived).onDone(() {
          if (!mounted) return;
          setState(() {
            _connectedDeviceName = '';
            _connection = null;
          });
          _showConnectionStatus(
              '${getLocalizedValue('bluetoothDisconnect')} ${device.name}');
        });
      } else {
        setState(() {
          _connectedDeviceName = '';
        });
        _showConnectionStatus(
            '${getLocalizedValue('bluetoothFail')} ${device.name}');
      }
    } catch (e) {
      setState(() {
        _connectedDeviceName = '';
      });
      _showConnectionStatus(
          '${getLocalizedValue('bluetoothFail')} ${device.name}.');
    }
  }

  void _showConnectionStatus(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onDataReceived(Uint8List data) {
    // 데이터를 문자열로 변환
    String receivedText = utf8.decode(data);
    // print('receivedText: $receivedText');
    List<String> values =
        receivedText.split(',').map((e) => e.trim()).toList(); // 공백 제거 및 쉼표로 분할
    _updatesensorData(values);
  }

  void _sendJoystickCommand() {
    String Command = '';

    if (_lastLeftY == 0 && _lastRightX != 0) {
      Command = _lastRightX < 0 ? 'L' : 'R';
      int degree = min((_lastRightX * 15).toInt().abs(), 9);
      _sendMessage(degree.toString() + Command);
    }

    if (_lastLeftY != 0 && _lastRightX == 0) {
      Command = _lastLeftY < 0 ? 'F' : 'B';
      int speed = min((_lastLeftY * 15).toInt().abs(), 9);
      _sendMessage(speed.toString() + Command);
    }

    int speed = min((_lastLeftY * 15).toInt().abs(), 9);

    // 대각선 방향 계산
    if (_lastLeftY != 0 && _lastRightX != 0) {
      if (_lastLeftY < 0 && _lastRightX < 0) {
        _sendMessage(speed.toString() + 'G'); // 왼쪽 위
      } else if (_lastLeftY < 0 && _lastRightX > 0) {
        _sendMessage(speed.toString() + 'I'); // 오른쪽 위
      } else if (_lastLeftY > 0 && _lastRightX < 0) {
        _sendMessage(speed.toString() + 'H'); // 왼쪽 아래
      } else if (_lastLeftY > 0 && _lastRightX > 0) {
        _sendMessage(speed.toString() + 'J'); // 오른쪽 아래
      }
    }
  }

  void _updateJoystickState(
      double leftX, double leftY, double rightX, double rightY) {
    _lastLeftX = leftX;
    _lastLeftY = leftY;
    _lastRightX = rightX;
    _lastRightY = rightY;
    _sendJoystickCommand();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/background.png'), // 배경 이미지 경로 설정
          fit: BoxFit.cover, // 이미지를 화면에 맞게 늘리거나 줄임
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // 상단 정렬을 제거합니다.
        children: [
          Align(
            alignment: Alignment.topCenter, // 내용을 상단 중앙에 정렬
            child: Stack(
              children: [
                // upperbackground1
                Positioned.fill(
                  child: Image.asset(
                    'images/upperbackground1.png',
                    fit: BoxFit.fill,
                  ),
                ),
                // upperbackground2
                Positioned.fill(
                  child: Image.asset(
                    'images/upperbackground2.png',
                    fit: BoxFit.contain,
                  ),
                ),
                // upperbackground3
                Positioned(
                  top: 0, // 상단에 정렬
                  left: 0,
                  right: 0,
                  // height: 8.0,
                  child: Image.asset(
                    'images/upperbackground3.png',
                    fit: BoxFit.fill,
                  ),
                ),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // 전체 Row의 자식들을 상하 중앙 정렬
                    children: [
                      // 연결된 장치 정보
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              bottom: 7.0, top: 0.0, left: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment
                                .start, // Column 내부에서 시작 정렬 유지
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // 이 Row의 자식들도 상하 중앙 정렬
                                children: [
                                  Text(
                                    '${getLocalizedValue('connected')}: $_connectedDeviceName',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.016,
                                      fontFamily: 'pretendard',
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF181D27),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTapDown: (_) => setState(
                                        () => _isBluetoothButtonPressed = true),
                                    onTapUp: (_) => setState(() =>
                                        _isBluetoothButtonPressed = false),
                                    onTapCancel: () => setState(() =>
                                        _isBluetoothButtonPressed = false),
                                    onTap: () {
                                      _selectBluetoothConnection();
                                    },
                                    child: Container(
                                      width: screenWidth * 0.07,
                                      height: screenWidth * 0.07,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: AssetImage(_isBluetoothButtonPressed
                                              ? 'images/pressedmanualbutton.png' // 눌린 상태 이미지
                                              : 'images/manualbutton.png'), // 일반 상태 이미지
                                          // fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.bluetooth,
                                        color: _connectedDeviceName == ''
                                            ? Colors.white
                                            : Colors.blue,
                                        size: screenWidth * 0.02,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 언어 선택 버튼
                      Expanded(
                        child: Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment:
                                CrossAxisAlignment.center, // 중앙 정렬 적용
                            children: [
                              IconButton(
                                icon: Icon(Icons.language),
                                color: Colors.white,
                                onPressed: () => _showLanguagePicker(context),
                                iconSize: screenWidth * 0.03,
                                padding: EdgeInsets.only(
                                  right: screenWidth * 0.02,
                                  left: screenWidth * 0.02,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.settings),
                                color: Colors.white,
                                iconSize: screenWidth * 0.03,
                                padding: EdgeInsets.only(
                                  right: screenWidth * 0.02,
                                  left: screenWidth * 0.02,
                                ),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SettingsScreen(),
                                    ),
                                  );
                                  SystemChrome.setEnabledSystemUIMode(
                                      SystemUiMode.manual,
                                      overlays: []);
                                  loadButtonValues();
                                  loadsensorVisibility();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 설정 버튼
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              bottom: 7.0, top: 0.0, right: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment
                                .center, // 이 Row의 자식들을 상하 중앙 정렬
                            children: [
                              GestureDetector(
                                onTapDown: (_) {
                                  setState(() {
                                    youtubebutton_isPressed = true;
                                  });
                                },
                                onTapUp: (_) {
                                  setState(() {
                                    youtubebutton_isPressed = false;
                                  });
                                  final Uri _url = Uri.parse(
                                      "https://www.youtube.com/playlist?list=PLWOLBPcViPKLA-19AZbEdITSVv0rjUGqX");
                                  _launchUrl(_url);
                                },
                                onTapCancel: () {
                                  setState(() {
                                    youtubebutton_isPressed = false;
                                  });
                                },
                                child: youtubebutton_isPressed
                                    ? Image.asset(
                                        'images/pressedyoutubebutton.png',
                                        width: screenWidth * 0.07,
                                        height: screenWidth * 0.07,
                                      )
                                    : Image.asset(
                                        'images/youtubebutton.png',
                                        width: screenWidth * 0.07,
                                        height: screenWidth * 0.07,
                                      ),
                              ),
                              GestureDetector(
                                onTapDown: (_) {
                                  setState(() {
                                    manualbutton_isPressed = true;
                                  });
                                },
                                onTapUp: (_) {
                                  setState(() {
                                    manualbutton_isPressed = false;
                                  });
                                  final Uri _url =
                                      Uri.parse(getLocalizedValue('manualUri'));
                                  _launchUrl(_url);
                                },
                                onTapCancel: () {
                                  setState(() {
                                    manualbutton_isPressed = false;
                                  });
                                },
                                child: Stack(
                                  children: [
                                    manualbutton_isPressed
                                        ? Image.asset(
                                            'images/pressedmanualbutton.png',
                                            width: screenWidth * 0.07,
                                            height: screenWidth * 0.07,
                                          )
                                        : Image.asset(
                                            'images/manualbutton.png',
                                            width: screenWidth * 0.07,
                                            height: screenWidth * 0.07,
                                          ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: Text(
                                          getLocalizedValue('manual'),
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.013,
                                            fontFamily: 'Pretendard',
                                            fontWeight:
                                                FontWeight.w600, // semibold
                                            color: manualbutton_isPressed
                                                ? Color(0xFF818181)
                                                : Color(0xFFFFFFFF),
                                          ),
                                        ),
                                      ),
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

          // 상단 버튼들
          Padding(
            padding: EdgeInsets.only(
                top: screenWidth * 0.01,
                left: screenWidth * (0.15 - buttonValues.length * 0.01),
                right: screenWidth * (0.15 - buttonValues.length * 0.01)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                buttonValues.length,
                (index) => buildButton(index),
              ),
            ),
          ),

          Expanded(
            child: Stack(
                fit: StackFit.expand, // Stack이 자식의 크기에 맞게 확장되도록 설정
                children: [
                  // 배경 왼쪽 열
                  Positioned(
                    left: 0, // 왼쪽 하단에 고정
                    bottom: 0, // 왼쪽 하단에 고정
                    child: Container(
                      width: screenWidth * 0.1, // 너비 설정
                      height: screenWidth * 0.1, // 높이 설정
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image:
                              AssetImage('images/lowerleft.png'), // 이미지 파일 경로
                          fit: BoxFit.contain, // 이미지를 컨테이너에 맞게 조절
                        ),
                      ),
                    ),
                  ),

                  // 배경 오른쪽 열
                  Positioned(
                    right: 0, // 오른쪽 하단에 고정
                    bottom: 0, // 오른쪽 하단에 고정
                    child: Container(
                      width: screenWidth * 0.1, // 너비 설정
                      height: screenWidth * 0.1, // 높이 설정
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image:
                              AssetImage('images/lowerright.png'), // 이미지 파일 경로
                          fit: BoxFit.contain, // 이미지를 컨테이너에 맞게 조절
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0, // 왼쪽으로부터 시작
                    right: 0, // 오른쪽으로부터 시작하여 화면 전체 너비를 채움
                    bottom: 0, // 하단에 고정
                    height: screenWidth * 0.1, // 고정된 높이 설정
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                              'images/lowerbackground.png'), // 이미지 파일 경로
                          fit: BoxFit.fill, // 이미지를 너비에 맞게 조절하면서 높이를 채움
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0, // 왼쪽으로부터 시작
                    right: 0, // 오른쪽으로부터 시작하여 화면 전체 너비를 채움
                    bottom: 0, // 하단에 고정
                    height: screenWidth * 0.1, // 고정된 높이 설정
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image:
                              AssetImage('images/lowermidle.png'), // 이미지 파일 경로
                          fit: BoxFit.contain, // 이미지를 너비에 맞게 조절하면서 높이를 채움
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 25),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 30.0),
                                  child: LeftJoystick(
                                    onDirectionChanged: (double x, double y) {
                                      _updateJoystickState(
                                          x, y, _lastRightX, _lastRightY);
                                    },
                                    onStop: () {
                                      if (_lastRightX == 0) {
                                        _sendMessage('S');
                                      }
                                      _lastLeftY = 0.0;
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    EdgeInsets.only(top: 0.0, bottom: 20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${getLocalizedValue('sensor')}',
                                      style: TextStyle(
                                        fontFamily: 'pretendard',
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFFFFFF),
                                        height: 0.3, // 텍스트의 라인 높이 감소
                                      ),
                                    ),
                                    CustomToggleButton(
                                      isToggleOn: _isToggleOn,
                                      onToggle: _toggleButton,
                                    ),
                                    Visibility(
                                      visible: _isToggleOn &&
                                          sensorVisibility.isNotEmpty,
                                      maintainSize: true, // 이 부분을 추가합니다.
                                      maintainAnimation: true,
                                      maintainState: true,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage(
                                                "images/sensorbackground.png"),
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Table(
                                            columnWidths: {
                                              0: FixedColumnWidth(
                                                  screenWidth * 0.062),
                                              1: FixedColumnWidth(
                                                  screenWidth * 0.003),
                                              2: FixedColumnWidth(
                                                  screenWidth * 0.062),
                                              3: FixedColumnWidth(
                                                  screenWidth * 0.062),
                                              4: FixedColumnWidth(
                                                  screenWidth * 0.003),
                                              5: FixedColumnWidth(
                                                  screenWidth * 0.062),
                                            },
                                            children: [
                                              for (int row = 0;
                                                  row <
                                                      (sensorNames.length +
                                                              1) ~/
                                                          2;
                                                  row++)
                                                TableRow(
                                                  children: [
                                                    for (int col = 0;
                                                        col < 2;
                                                        col++)
                                                      if (row +
                                                              col *
                                                                  ((sensorNames
                                                                              .length +
                                                                          1) ~/
                                                                      2) <
                                                          sensorNames
                                                              .length) ...[
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                            left: screenWidth *
                                                                0.01,
                                                            top: screenWidth *
                                                                0.013,
                                                            bottom:
                                                                screenWidth *
                                                                    0.013,
                                                          ),
                                                          child: Align(
                                                            alignment: Alignment
                                                                .center,
                                                            child: Text(
                                                              '${sensorNames[row + col * ((sensorNames.length + 1) ~/ 2)]}',
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'pretendard',
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: sensorVisibility[row +
                                                                        col *
                                                                            ((sensorNames.length + 1) ~/
                                                                                2)]
                                                                    ? Color(
                                                                        0xFFFFFFFF)
                                                                    : Color(
                                                                        0x4FFFFFFF),
                                                                fontSize:
                                                                    screenWidth *
                                                                        0.013,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Center(
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                              top: screenWidth *
                                                                  0.013,
                                                              bottom:
                                                                  screenWidth *
                                                                      0.013,
                                                            ),
                                                            child: Text(
                                                              ':',
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'pretendard',
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color: sensorVisibility[row +
                                                                        col *
                                                                            ((sensorNames.length + 1) ~/
                                                                                2)]
                                                                    ? Color(
                                                                        0xFFFFFFFF)
                                                                    : Color(
                                                                        0x4FFFFFFF),
                                                                fontSize:
                                                                    screenWidth *
                                                                        0.013,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Visibility(
                                                          visible: sensorVisibility[row +
                                                              col *
                                                                  ((sensorNames
                                                                              .length +
                                                                          1) ~/
                                                                      2)],
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                              right:
                                                                  screenWidth *
                                                                      0.01,
                                                              top: screenWidth *
                                                                  0.013,
                                                              bottom:
                                                                  screenWidth *
                                                                      0.013,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              child: Text(
                                                                '${sensorData[sensorNames[row + col * ((sensorNames.length + 1) ~/ 2)]]}',
                                                                style:
                                                                    TextStyle(
                                                                  fontFamily:
                                                                      'pretendard',
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  color: Color(
                                                                      0xFFFFFFFF),
                                                                  fontSize:
                                                                      screenWidth *
                                                                          0.013,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ] else ...[
                                                        const SizedBox.shrink(),
                                                        const SizedBox.shrink(),
                                                        const SizedBox.shrink(),
                                                      ]
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right: 30.0), // 오른쪽에 여백을 추가
                                  child: RightJoystick(
                                    onDirectionChanged: (double x, double y) {
                                      _updateJoystickState(
                                          _lastLeftX, _lastLeftY, x, y);
                                    },
                                    onStop: () {
                                      if (_lastLeftY == 0) {
                                        _sendMessage('S');
                                      }
                                      _lastRightX = 0.0;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
          ),
        ],
      ),
    );
  }
}

class CustomButton extends StatefulWidget {
  final int index;
  final VoidCallback onPressed;

  const CustomButton({
    Key? key,
    required this.index,
    required this.onPressed,
  }) : super(key: key);

  @override
  _CustomButtonState createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: screenWidth * 0.085,
      height: screenWidth * 0.085,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _isPressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _isPressed = false;
          });
          widget.onPressed();
        },
        onTapCancel: () {
          setState(() {
            _isPressed = false;
          });
        },
        child: Stack(
          children: [
            Image.asset(
              _isPressed ? 'images/pressedbutton.png' : 'images/button.png',
              width: screenWidth * 0.085,
              height: screenWidth * 0.085,
            ),
            Center(
              child: Text(
                buttonValues[widget.index], // 버튼 값 표시
                style: TextStyle(
                  color: _isPressed
                      ? Color(0xFFFFFFFF)
                      : Color(0xFFFF6E23), // 눌렸을 때와 안 눌렸을 때의 텍스트 색상 설정
                  fontSize: screenWidth * 0.045, // 텍스트 크기 설정
                  fontFamily: 'gwtt',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////
class LeftJoystick extends StatefulWidget {
  final Function(double x, double y) onDirectionChanged;
  final VoidCallback onStop;

  const LeftJoystick({
    Key? key,
    required this.onDirectionChanged,
    required this.onStop,
  }) : super(key: key);

  @override
  _LeftJoystickState createState() => _LeftJoystickState();
}

class _LeftJoystickState extends State<LeftJoystick> {
  String imagePath = 'images/leftjoystick.png'; // 초기 이미지 설정

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return JoystickArea(
      listener: (StickDragDetails details) {
        setState(() {
          // 조이스틱이 중앙에 있을 때 기본 이미지
          if (details.x == 0 && details.y == 0) {
            imagePath = 'images/leftjoystick.png';
            widget.onStop();
          } else {
            // 조이스틱이 위로 움직였을 때
            if (details.y < 0) {
              imagePath = 'images/leftjoystickup.png';
            }
            // 조이스틱이 아래로 움직였을 때
            else if (details.y > 0) {
              imagePath = 'images/leftjoystickdown.png';
            }
            // debugPrint("imagePath: $imagePath");

            widget.onDirectionChanged(details.x, details.y);
          }
        });
      },

      period: Duration(milliseconds: 100),
      mode: JoystickMode.vertical,
      child: Center(),
      base: Image.asset(imagePath,
          width: screenWidth * 0.24,
          height: screenWidth * 0.24), // 변경된 이미지를 기반으로 위젯을 다시 그림
      initialJoystickAlignment: Alignment.center,
      stick: Image.asset('images/joystickstick.png',
          width: screenWidth * 0.12, height: screenWidth * 0.12),
    );
  }
}

//////////////////////////////////////////////////////////////////////////////

class RightJoystick extends StatefulWidget {
  final Function(double x, double y) onDirectionChanged;
  final VoidCallback onStop;

  const RightJoystick({
    Key? key,
    required this.onDirectionChanged,
    required this.onStop,
  }) : super(key: key);

  @override
  _RightJoystickState createState() => _RightJoystickState();
}

class _RightJoystickState extends State<RightJoystick> {
  String imagePath = 'images/rightjoystick.png'; // 초기 이미지 설정

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return JoystickArea(
      listener: (StickDragDetails details) {
        setState(() {});
        // 조이스틱이 중앙에 있을 때 기본 이미지
        if (details.x == 0 && details.y == 0) {
          imagePath = 'images/rightjoystick.png';
          widget.onStop();
        } else {
          // 조이스틱이 위로 움직였을 때
          if (details.x < 0) {
            imagePath = 'images/rightjoystickleft.png';
          }
          // 조이스틱이 아래로 움직였을 때
          else if (details.x > 0) {
            imagePath = 'images/rightjoystickright.png';
          }
          // debugPrint("imagePath: $imagePath");

          widget.onDirectionChanged(details.x, details.y);
        }
      },
      period: Duration(milliseconds: 100),
      mode: JoystickMode.horizontal,
      child: Center(),
      base: Image.asset(imagePath,
          width: screenWidth * 0.24,
          height: screenWidth * 0.24), // 변경된 이미지를 기반으로 위젯을 다시 그림
      initialJoystickAlignment: Alignment.center,
      stick: Image.asset('images/joystickstick.png',
          width: screenWidth * 0.12, height: screenWidth * 0.12),
    );
  }
}

class CustomToggleButton extends StatefulWidget {
  final bool isToggleOn;
  final Function(bool) onToggle;

  const CustomToggleButton({
    Key? key,
    required this.isToggleOn,
    required this.onToggle,
  }) : super(key: key);

  @override
  _CustomToggleButtonState createState() => _CustomToggleButtonState();
}

class _CustomToggleButtonState extends State<CustomToggleButton> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () {
        widget.onToggle(!widget.isToggleOn);
      },
      child: Image.asset(
        widget.isToggleOn ? 'images/toggleon.png' : 'images/toggleoff.png',
        width: screenWidth * 0.07,
        height: screenWidth * 0.07,
      ),
    );
  }
}
