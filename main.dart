import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordivate',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        appBarTheme: const AppBarTheme(
          color: Color.fromARGB(255, 63, 65, 66),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class WordEntry {
  final String word;
  final String definition;
  final DateTime dateAdded;

  WordEntry({required this.word, required this.definition, required this.dateAdded});

  Map<String, dynamic> toJson() => {
        'word': word,
        'definition': definition,
        'dateAdded': dateAdded.toIso8601String(),
      };

  static WordEntry fromJson(Map<String, dynamic> json) => WordEntry(
        word: json['word'],
        definition: json['definition'],
        dateAdded: DateTime.parse(json['dateAdded']),
      );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<String> _messages = [];
  List<WordEntry> _words = [];
  final TextEditingController _controller = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _recorder.openRecorder();
  }

  Future<void> _loadWords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedWords = prefs.getStringList('words');
    if (storedWords != null) {
      setState(() {
        _words = storedWords.map((word) => WordEntry.fromJson(json.decode(word))).toList();
      });
    }
  }

  Future<void> _saveWords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> storedWords = _words.map((word) => json.encode(word.toJson())).toList();
    prefs.setStringList('words', storedWords);
  }

  void _sendMessage() async {
    print('Send button pressed');
    String message = _controller.text.trim();
    print('Message: $message');
    
    if (message.isNotEmpty) {
      String response = await _getResponse(message);
      WordEntry newEntry = WordEntry(word: message, definition: response, dateAdded: DateTime.now());

      setState(() {
        _messages.add('You: $message');
        _messages.add('Wordivate: $response');
        _words.add(newEntry);
        _controller.clear();
      });

      await _saveWords();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid message.')),
      );
    }
  }

  Future<String> _getResponse(String input) async {
    final url = Uri.parse('https://api.gemini.com/v1/words/$input'); // Update with the correct Gemini API endpoint
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (input.split(' ').length > 1) {
        // Handle sentence input
        if (data.isNotEmpty && data['word'] != null) {
          return data['word'];
        } else {
          return 'No word found for the given sentence.';
        }
      } else {
        // Handle single word input
        if (data.isNotEmpty && data['meanings'].isNotEmpty) {
          final definition = data['meanings'][0]['definitions'][0]['definition'];
          return definition;
        } else {
          return 'No definition found.';
        }
      }
    } else {
      return 'Error fetching response.';
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearChat,
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.grey[900], // Set the background color to dark gray
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 63, 65, 66), // Match AppBar color
                ),
                child: Text(
                  'Menu',
                  style: TextStyle(
                    color: Color.fromARGB(255, 189, 220, 232),
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.white),
                title: const Text('Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list, color: Colors.white),
                title: const Text('Stored Words', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WordListScreen(words: _words)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('Settings', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.white),
                title: const Text('About', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to about page
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.grey[900], // Set the background color to dark gray
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _messages[index],
                    style: const TextStyle(color: Colors.white), // Set text color to white
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter your message',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WordListScreen extends StatefulWidget {
  final List<WordEntry> words;

  const WordListScreen({Key? key, required this.words}) : super(key: key);

  @override
  _WordListScreenState createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  List<WordEntry> _sortedWords = [];
  bool _isAscending = true;
  String _sortCriteria = 'dateAdded';

  @override
  void initState() {
    super.initState();
    _sortedWords = widget.words;
  }

  void _sortWords() {
    setState(() {
      if (_sortCriteria == 'dateAdded') {
        _sortedWords.sort((a, b) => _isAscending ? a.dateAdded.compareTo(b.dateAdded) : b.dateAdded.compareTo(a.dateAdded));
      } else if (_sortCriteria == 'alphabetically') {
        _sortedWords.sort((a, b) => _isAscending ? a.word.compareTo(b.word) : b.word.compareTo(a.word));
      }
    });
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sort Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('Date Added'),
                leading: Radio<String>(
                  value: 'dateAdded',
                  groupValue: _sortCriteria,
                  onChanged: (String? value) {
                    setState(() {
                      _sortCriteria = value!;
                    });
                    Navigator.of(context).pop();
                    _sortWords();
                  },
                ),
              ),
              ListTile(
                title: const Text('Alphabetically'),
                leading: Radio<String>(
                  value: 'alphabetically',
                  groupValue: _sortCriteria,
                  onChanged: (String? value) {
                    setState(() {
                      _sortCriteria = value!;
                    });
                    Navigator.of(context).pop();
                    _sortWords();
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Ascending'),
                value: _isAscending,
                onChanged: (bool value) {
                  setState(() {
                    _isAscending = value;
                  });
                  Navigator.of(context).pop();
                  _sortWords();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stored Words'),
        backgroundColor: const Color.fromARGB(255, 63, 65, 66), // Match AppBar color
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      backgroundColor: Colors.grey[900], // Set the background color to dark gray
      body: ListView.builder(
        itemCount: _sortedWords.length,
        itemBuilder: (context, index) {
          final wordEntry = _sortedWords[index];
          return Card(
            color: Colors.grey[800], // Set card background color
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ListTile(
              title: Text(
                wordEntry.word,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Definition: ${wordEntry.definition}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Date Added: ${wordEntry.dateAdded.toLocal()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color.fromARGB(255, 63, 65, 66), // Match AppBar color
      ),
      backgroundColor: Colors.grey[900], // Set the background color to dark gray
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.language, color: Colors.white),
            title: const Text('Language', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Navigate to language selection screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications, color: Colors.white),
            title: const Text('Notifications', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Navigate to notification settings screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.white),
            title: const Text('Clear Data', style: TextStyle(color: Colors.white)),
            onTap: _clearData,
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.white),
            title: const Text('About', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Navigate to about screen
            },
          ),
        ],
      ),
    );
  }

  Future<void> _clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data cleared successfully.')),
    );
  }
}
