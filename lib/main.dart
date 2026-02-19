import 'package:flutter/material.dart';

void main() {
  runApp(const StoicApp());
}

class StoicApp extends StatelessWidget {
  const StoicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barry的斯多葛名言',
      debugShowCheckedModeBanner: false,
      // 浅色主题
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.grey,
        brightness: Brightness.light,
      ),
      // 深色主题
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.dark,
      ),
      // 自动跟随系统颜色
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 40),
              const Text(
                "“我们遭受的痛苦，\n在想象中远比在现实中更多。”",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 20),
              const Text(
                "— 塞内卡",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () {
                  // 这里以后可以加切换名言的逻辑
                },
                child: const Text("获取智慧"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}