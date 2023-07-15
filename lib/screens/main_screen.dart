import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver{
  
  bool permissionGranted = false;
  late final Future<void> _future;
  String text = "";

  CameraController? _cameraController;

  final _textRecognizer = TextRecognizer();

  Timer? timer;

  List<bool> _selections = List.generate (2, (_) => false);


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _future = _requestCameraPermission();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {_scanImage();});
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _textRecognizer.close();
    timer?.cancel();
    super.dispose();
  }


  @override
  void didChangeAppLifeCycleState(AppLifecycleState state) {
    if (_cameraController == null || _cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _cameraController != null && _cameraController!.value.isInitialized) {
      _startCamera();
    }
  }


  void _updateZoomLevel(int inOrOut) {
    if (inOrOut == 1) {
      _cameraController!.setZoomLevel(15.0);
    } else {
      _cameraController!.setZoomLevel(4.0);
    }
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) { 
        return Scaffold(
          backgroundColor: Colors.blueGrey,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
      
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.15,
                child: Center(
                  child: ListTile(
                    subtitle: permissionGranted 
                    ? const Text('Permission Granted')
                    : const Text('Permission denied'),
                    trailing: ToggleButtons(
                      isSelected: _selections,
                      onPressed: (index) => _updateZoomLevel(index),
                      children: const [
                        Icon(
                          Icons.remove,
                          color: Colors.black,
                        ),
                        Icon(
                          Icons.add,
                          color: Colors.black,
                        )
                      ], 
                    ),
                  ),
                ),
              ),
      
              Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    children: [
                      if (permissionGranted)
                        FutureBuilder<List<CameraDescription>>(
                          future: availableCameras(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              _initCameraController(snapshot.data!);

                              return Center(child: CameraPreview(_cameraController!),);
                            } else {
                              return const LinearProgressIndicator();
                            }
                        },
                      ) else 
                      Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        width: MediaQuery.of(context).size.width * 0.8,
                        color: Colors.blue,
                      )
                    ],
                  ),
                ),
              ),
      
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.25,
                width: MediaQuery.of(context).size.width * 0.9,
                child: Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.2,
                    width: MediaQuery.of(context).size.width * 0.85,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      color: Colors.grey
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        text
                      ),
                    ),
                  ),
                ),
              )
      
            ],
          ),
        );
      }
    );
  }



  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    permissionGranted = status == PermissionStatus.granted;
  }


  void _startCamera() {
    if (_cameraController != null) {
      _cameraSelected(_cameraController!.description);
    }
  }


  void _stopCamera() {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
  }


  void _initCameraController(List<CameraDescription> cameras) {
    if (_cameraController != null) {
      return;
    }


    CameraDescription? camera;
    for (var i = 0; i < cameras.length; i++) {
      final CameraDescription current = cameras[i];
      if (current.lensDirection == CameraLensDirection.back) {
        camera = current;
        break;
      }
    }


    if (camera != null) {
      _cameraSelected(camera);
    }
  }


  Future<void> _cameraSelected(CameraDescription camera) async {
    double maxzoomLevel = 1.0;
    _cameraController = CameraController(
      camera, 
      ResolutionPreset.max, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController?.initialize();
    
    _cameraController!
      .getMinZoomLevel()
      .then((value) => maxzoomLevel = value);

    _cameraController!.setZoomLevel(15.0);

    if (!mounted) {
      return;
    }
    setState(() {});
  }


  Future<void> _scanImage() async {
    if (_cameraController == null) return;

    final navigator = Navigator.of(context);

    try {
      final pictureFile = await _cameraController!.takePicture();

      final file = File(pictureFile.path);

      final inputImage = InputImage.fromFile(file);

      final recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        text = recognizedText.text;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An error occured while scanning')));
    }
  }
}