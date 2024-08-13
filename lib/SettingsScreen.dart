import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'global.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';


class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  KeyboardVisibilityController? keyboardVisibilityController;

  String getLocalizedValue(String key) {
    Map<String, Map<String, String>> localizedValues = {
      'en': {
        'settings': 'Settings',
        'buttonSettings': 'Button Settings',
        'button': 'Button',
        'reservedWords': 'Reserved words',
        'forward': 'Forward',
        'backward': 'Backward',
        'right': 'Right',
        'left': 'Left',
        'rightUp': 'RightUP',
        'leftUp': 'leftUp',
        'rightDown': 'rightDown',
        'leftDown': 'leftDown',
        'sensorOn': 'sensor On',
        'sensorOff': 'sensor off',
        'speed': 'speed',
        'sensorSettings': 'Sensor Settings',
        'sensor': 'Sensor',
        'addsensor': 'Add sensor',
        'addButton': 'Add Button',
        'maxButton': 'Maximum number of buttons reached (9)',
      },
      'ko': {
        'settings': '설정',
        'buttonSettings': '버튼 설정',
        'button': '버튼',
        'reservedWords': '예약어',
        'forward': '전진',
        'backward': '후진',
        'right': '우회전',
        'left': '좌회전',
        'rightUp': '전진 우회전',
        'leftUp': '전진 좌회전',
        'rightDown': '후진 우회전',
        'leftDown': '후진 좌회전',
        'sensorOn': '센서 켜기',
        'sensorOff': '센서 끄기',
        'speed': '속도',
        'sensorSettings': '센서 설정',
        'sensor': '센서',
        'addsensor': '신호 추가',
        'addButton': '버튼 추가',
        'maxButton': '버튼은 최대 9개까지 생성할 수 있습니다.',
      }
    };
    String langCode = Global.isKorean ? 'ko' : 'en';
    return localizedValues[langCode]![key]!;
  }

  List<TextEditingController> buttonControllers = [];
  List<String> buttonValues = ['W', 'w', 'X', 'x', 'v'];

  List<String> sensorNames = ['소리', '빛', '거리', 'X축', 'Y축', 'Z축'];
  List<TextEditingController> sensorControllers = [];
  List<bool> sensorChecks = [true,true,true,true,true,true];

  @override
  void initState() {
    super.initState();
    keyboardVisibilityController = KeyboardVisibilityController();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
    ]);
    keyboardVisibilityController!.onChange.listen((bool visible) {
      if (visible) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      }
    });
    loadSettings();  // 설정 로드
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]); // 페이지 벗어날 때 가로 방향으로 다시 설정
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> loadedButtonValues = prefs.getStringList('buttonValues') ?? ['W', 'w', 'X', 'x', 'v'];
    buttonValues = loadedButtonValues;
    buttonControllers = buttonValues.map((value) => TextEditingController(text: value)).toList();
    setState(() {});
    loadsensorNames(prefs);
  }

  Future<void> saveButtonValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('buttonValues', buttonValues);
  }

  void addButton() {
    if (buttonControllers.length < 9) { // 최대 9개의 버튼만 허용
      setState(() {
        int newButtonIndex = buttonControllers.length + 1; // 새 버튼의 번호
        buttonControllers.add(TextEditingController(text: '$newButtonIndex'));
        buttonValues.add('$newButtonIndex');
        saveButtonValues(); // SharedPreferences에 버튼 값 저장
      });
    } else {
      // 버튼 개수가 최대값에 도달했을 때 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getLocalizedValue('maxButton')),
            duration: Duration(seconds: 1),
          )
      );
    }
  }

  void removeButton(int index) {
    if (buttonControllers.length > 1) {
      setState(() {
        buttonControllers[index].dispose();
        buttonControllers.removeAt(index);
        buttonValues.removeAt(index);
        saveButtonValues();
      });
    }
  }

  void loadsensorNames(SharedPreferences prefs) {
    sensorNames = prefs.getStringList('sensorNames') ?? ['소리', '빛', '거리', 'X축', 'Y축', 'Z축'];
    sensorControllers = sensorNames.map((name) => TextEditingController(text: name)).toList();
    sensorChecks = List.generate(sensorNames.length, (index) {
        return prefs.getBool('sensorCheck_$index') ?? true;
    });

    setState(() {});
  }

  Future<void> savesensorNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sensorNames', sensorNames);
  }

  Widget buildSettingsSection(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget buildsensorSettingsSection(String title) {
    return buildSettingsSection(title, [
      ...sensorControllers.asMap().entries.map((entry) {
        int idx = entry.key;
        TextEditingController controller = entry.value;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: '${getLocalizedValue('sensor')} ${idx + 1}'),
                onChanged: (value) {
                  sensorNames[idx] = value;
                  savesensorNames();
                },
              ),
            ),
            Checkbox(
              value: sensorChecks[idx],
              onChanged: (bool? value) {
                setState(() {
                  sensorChecks[idx] = value!;
                });
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setBool('sensorCheck_$idx', value!);
                });
              },
            ),
          ],
        );
      }).toList(),
    ]);
  }



  Widget buildButtonSettingsSection(String title) {
    return buildSettingsSection(title, [
      ...buttonControllers.asMap().entries.map((entry) {
        int index = entry.key;
        TextEditingController controller = entry.value;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: '${getLocalizedValue('button')} ${index + 1}'),
                onChanged: (value) {
                  buttonValues[index] = value;
                  saveButtonValues();
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.remove_circle_outline),
              onPressed: () => removeButton(index),
            ),
          ],
        );
      }).toList(),
      SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: addButton,
            child: Text(getLocalizedValue('addButton')),
          ),
        ],
      ),
      Text(
        '\n'
            '*${getLocalizedValue('reservedWords')}\n'
            '${getLocalizedValue('forward')}: F\n'
            '${getLocalizedValue('backward')}: B\n'
            '${getLocalizedValue('right')}: R\n'
            '${getLocalizedValue('left')}: L\n'
            '${getLocalizedValue('leftUp')}: G\n'
            '${getLocalizedValue('rightUp')}: I\n'
            '${getLocalizedValue('leftDown')}: H\n'
            '${getLocalizedValue('rightDown')}: J\n'
            '${getLocalizedValue('sensorOn')}: O\n'
            '${getLocalizedValue('sensorOff')}: o\n'
            '${getLocalizedValue('speed')}: 0~9',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ]);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getLocalizedValue('settings')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildButtonSettingsSection(getLocalizedValue('buttonSettings')),
                buildsensorSettingsSection(getLocalizedValue('sensorSettings')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}