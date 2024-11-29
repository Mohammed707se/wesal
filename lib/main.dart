import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحليل الأداء المسرحي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.cairoTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: Color(0xFF1A1A2E),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Color(0xFF16213E),
          shadowColor: Colors.deepPurple.shade200.withOpacity(0.5),
        ),
      ),
      home: VoiceToneAnalyzer(),
    );
  }
}

class VoiceToneAnalyzer extends StatefulWidget {
  @override
  _VoiceToneAnalyzerState createState() => _VoiceToneAnalyzerState();
}

class _VoiceToneAnalyzerState extends State<VoiceToneAnalyzer>
    with SingleTickerProviderStateMixin {
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String _progressText = '';
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> _loadingTexts = [
    'جاري استكشاف المشهد المسرحي...',
    'تحليل الأداء التمثيلي في تقدم...',
    'رصد نبرات الصوت الدرامية...',
    'تفكيك لغة الجسد والإيماءات...',
    'تحليل التعبيرات الممثل...',
    'تركيب التقييم الفني...',
    'توليد التقرير المسرحي...'
  ];
  int _currentLoadingTextIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowCompression: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _analysisResult = null;
        _errorMessage = null;
        _animationController.forward(from: 0);
      });
    }
  }

  Future<void> _analyzeVideo() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'يرجى اختيار مقطع مسرحي أولاً.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _currentLoadingTextIndex = 0;
      _progressText = _loadingTexts[_currentLoadingTextIndex];
      _analysisResult = null;
      _errorMessage = null;
    });

    Future<void> updateLoadingText() async {
      while (_isLoading) {
        await Future.delayed(Duration(seconds: 3));
        if (_currentLoadingTextIndex < _loadingTexts.length - 1) {
          setState(() {
            _currentLoadingTextIndex++;
            _progressText = _loadingTexts[_currentLoadingTextIndex];
          });
        }
      }
    }

    updateLoadingText();

    try {
      var apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';
      var uri = Uri.parse('$apiUrl/analyze/');
      var request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _selectedFile!.bytes!,
          filename: _selectedFile!.name,
          contentType: MediaType('video', 'mp4'),
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        var data = json.decode(responseBody);

        setState(() {
          _analysisResult = data;
          _isLoading = false;
          _progressText = '';
          _animationController.forward(from: 0);
        });
      } else {
        setState(() {
          _errorMessage =
              'فشل التحليل: ${response.statusCode} - ${response.reasonPhrase}';
          _isLoading = false;
          _progressText = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ: $e';
        _isLoading = false;
        _progressText = '';
      });
    }
  }

  Widget _buildProgressIndicator() {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitWave(
            color: Colors.deepPurple,
            size: 70.0,
          ),
          SizedBox(height: 20),
          Text(
            _progressText,
            style: TextStyle(
              fontSize: 18,
              color: Colors.deepPurple.shade200,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    if (_analysisResult == null) return Container();

    return FadeTransition(
      opacity: _animation,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisCard(
              'تحليل النبرة الصوتية',
              _analysisResult!['audio_tone_analysis'] ?? '',
              Icons.mic,
            ),
            _buildAnalysisCard(
              'تحليل لغة الجسد',
              _analysisResult!['body_language_analysis'] ?? '',
              Icons.emoji_emotions,
            ),
            _buildAnalysisCard(
              'التحليل النهائي',
              _analysisResult!['final_analysis'] ?? '',
              Icons.theater_comedy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(String title, String content, IconData icon) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple, size: 30),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return Container();

    return Text(
      _errorMessage!,
      style: TextStyle(
        color: Colors.red.shade300,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تحليل الأداء المسرحي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: Icon(Icons.video_file),
                        label: Text('اختر مقطع مسرحي'),
                      ),
                      SizedBox(height: 15),
                      _selectedFile != null
                          ? Text(
                              'المقطع المحدد: ${_selectedFile!.name}',
                              style: TextStyle(
                                color: Colors.deepPurple.shade200,
                                fontSize: 14,
                              ),
                            )
                          : Text(
                              'لم يتم تحديد أي مقطع',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _analyzeVideo,
                        icon: Icon(Icons.analytics),
                        label: Text('ابدأ التحليل المسرحي'),
                      ),
                      SizedBox(height: 20),
                      _isLoading
                          ? _buildProgressIndicator()
                          : _buildErrorMessage(),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildAnalysisResult(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
