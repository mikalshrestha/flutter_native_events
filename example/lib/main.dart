import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_events/flutter_native_events.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> _log = <String>[];
  StreamSubscription<NativeEvent>? _allSubscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initBus();
  }

  @override
  void dispose() {
    _allSubscription?.cancel();
    NativeEvents.dispose();
    super.dispose();
  }

  Future<void> _initBus() async {
    await NativeEvents.init(
      config: const NativeEventConfig(
        enableLogging: true,
        replayLastEvent: true,
        requestTimeout: Duration(seconds: 3),
      ),
    );

    _allSubscription = NativeEvents.all.listen((event) {
      _addLog('all: ${event.source.name}:${event.name} ${event.data}');
    });

    setState(() => _initialized = true);
    _addLog('NativeEvents initialized');
  }

  Future<void> _emitLogout() async {
    await NativeEvents.emit('logout',
        data: <String, dynamic>{'reason': 'manual'});
    _addLog('Flutter emitted logout');
  }

  Future<void> _listenOnce() async {
    _addLog('Waiting once for payment_success');
    final event = await NativeEvents.once('payment_success');
    _addLog('once: ${event.name} ${event.data}');
  }

  Future<void> _requestAccount() async {
    try {
      final response = await NativeEvents.request(
        'select_account',
        data: <String, dynamic>{'currency': 'USD'},
      );
      _addLog('Account selected: ${response.data}');
    } on NativeEventException catch (error) {
      _addLog(error.toString());
    }
  }

  Future<void> _requestError() async {
    try {
      await NativeEvents.request('select_account_error');
    } on NativeEventException catch (error) {
      _addLog('Error response: $error');
    }
  }

  Future<void> _requestTimeout() async {
    try {
      await NativeEvents.request(
        'never_replies',
        timeout: const Duration(milliseconds: 500),
      );
    } on NativeEventTimeoutException catch (error) {
      _addLog('Timeout: $error');
    }
  }

  Future<void> _disposeBus() async {
    await _allSubscription?.cancel();
    _allSubscription = null;
    await NativeEvents.dispose();
    setState(() => _initialized = false);
    _addLog('NativeEvents disposed');
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String()}  $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Native Events')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    onPressed: _initialized ? _emitLogout : null,
                    child: const Text('Emit logout'),
                  ),
                  OutlinedButton(
                    onPressed: _initialized ? _listenOnce : null,
                    child: const Text('once() payment'),
                  ),
                  OutlinedButton(
                    onPressed: _initialized ? _requestAccount : null,
                    child: const Text('Request account'),
                  ),
                  OutlinedButton(
                    onPressed: _initialized ? _requestError : null,
                    child: const Text('Error reply'),
                  ),
                  OutlinedButton(
                    onPressed: _initialized ? _requestTimeout : null,
                    child: const Text('Timeout'),
                  ),
                  TextButton(
                    onPressed: _initialized ? _disposeBus : _initBus,
                    child: Text(_initialized ? 'Dispose' : 'Init'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Event log',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(_log[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
