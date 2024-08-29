# WizController

# 1. Window 환경 변수 설정, gradle 설정, sdk tools 설치, cordova 설치

## 1) Window 환경변수 설정 및 gradle 설정

사용자 변수> 각자 환경에 맞춰서 설정을 하면 됩니다.

- 추가 GRADLE_HOME (Gradle 7.6) : C:\Users\bryan\gradle-7.6
- 추가 JAVA_HOME (JDK 17) : C:\Program Files\Android\Android Studio\jbr
- 추가 ANDROID_HOME : C:\Users\bryan\AppData\Local\Android\Sdk
- 기존 Path 에 추가:
  - C:\Program Files\Android\Android Studio\jbr\bin
  - C:\Users\bryan\gradle-7.6\bin
  - C:\Users\bryan\AppData\Local\Android\Sdk\cmdline-tools\latest\bin
  - C:\Users\bryan\AppData\Local\Android\Sdk\platform-tools
  - C:\Users\bryan\AppData\Local\Android\Sdk\build-tools\34.0.0
  - C:\Users\bryan\AppData\Local\Android\Sdk\emulator

설정을 모두 확인합니다.

```
echo %ANDROID_HOME%
echo %JAVA_HOME%
echo %GRADLE_HOME%

adb --version
Android Debug Bridge version 1.0.41
Version 34.0.5-10900879
Installed as C:\Users\bryan\AppData\Local\Android\Sdk\platform-tools\adb.exe
Running on Windows 10.0.22621
```

- gradle은 따로 설치 없이 바이너리를 다운로드 후 압축 해제해서 원하는 위치에 두고 안드로이드 스튜디오에서 그레이들 홈 설정을 해도 됩니다.

## 2) sdk tools 설치

- 안드로이드 스튜디오에서 sdk tools를 설치해야 합니다.

개발은 flutter 를 사용해서 이루어지며, 안드로이드 스튜디오에서 개발합니다.

# 2.구글 플레이에 업로드를 위한 사전 작업

## 1) aab 파일 생성하기

안드로이드 스튜디오 상단의 Build - Flutter - Build App Bundel 을 클릭해 aab 파일을 생성합니다.

aab 파일은 ./rc_controller_app/build/app/outputs/bundle/release 경로에 생성됩니다.

## 2) 키스토어 파일 생성하기

관리자 모드로 cmd 실행 후 프로젝트 루트 경로에서 아래 명령을 실행한다. 키스토어 파일은 처음에 한 번만 생성하면 됩니다.
단, 보안에 각별히 유의해야 합니다. 외부 유출 금지! 파일 분실 하면 안 됩니다.
미리 생성해둔 키스토어 파일을 팀즈에서 공유하고 있으므로 담당자에게 문의바랍니다.

```
keytool -genkey -v -keystore codingschool.keystore -alias codingschool -keyalg RSA -keysize 2048 -validity 10000
```

## 3) 앱 서명하기

config.xml 파일을 열고 android-versionCode="정수값" 버전은 정수로 현재 설정 값보다 큰 숫자를 1씩 올리면서 프로덕션 빌드를 해야 합니다. (구글 정책)
platforms/android 하위에 ant-build 폴더를 생성하고 키스토어 파일을 옮깁니다.
프로덕션 빌드는 다음 명령을 사용합니다.

```
cordova build --release
```

정상적으로 빌드가 완료되면 platforms/android/app/build/outputs/bundle/release 폴더 하위에 app-release.aab 파일이 생성됩니다.
다음 빌드한 app-release.aab 파일을 platforms/android/ant-build 폴더에 복사하고 다음 명령을 관리자 cmd에서 실행합니다.
서명 시 비밀번호를 입력해야 합니다. 별도로 담당자나 대표님께 문의 바랍니다.

```
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore codingschool.keystore app-release.aab codingschool
```

## 4) aab 파일을 최적화하기

다음 명령을 사용하여 번들 파일을 최적화합니다.

```
zipalign -v 4 app-release.aab app-release-signed.aab
```

위 명령이 정상적으로 완료되면 platforms/android/ant-build 폴더에 app-release-signed.aab 파일이 생성됩니다.

## 5) 서명 된 앱을 구글 콘솔에서 업로드한다.

app-release-signed.aab 파일을 구글 콘솔에 업로드하여 심사를 거쳐서 배포합니다.
특정 이유로 거부 당하게 되면 수정 할 때 마다 새로운 번들을 만들어야 하는데 ./rc_controller_app/pubspec.yaml의 version: 1.0.0+"버전 숫자"를 1씩 증가시키고 1),2),3),4) 과정을 반복하면 됩니다.
