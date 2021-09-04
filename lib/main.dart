import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myapp/BoundingBox.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite/tflite.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;

const String ssd = "SSD MobileNet";
List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: Home(cameras)));
}

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;
  Home(this.cameras);
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Color hiconcolor;
  Color diconcolor;
  Color siconcolor;
  Color tcolor;
  Color bcolor;
  Color scolor;
  String bpic;
  Color boundingiconcolor = Colors.blueAccent;
  Color aiconcolor = Colors.blueAccent;
  final Color selected = Colors.blueAccent;
  final Color unselected = Colors.black;
  final Color unselecteddark = Colors.white;
  final Color overlayunselected = Colors.white;
  final Color overlaydisabled = Colors.grey;
  final Color textcolordark = Colors.white;
  final Color textcolor = Colors.black;
  final Color backgroundcolor = Colors.grey[100];
  final Color backgroundcolordark = Colors.black87;
  final Color shadowcolor = Colors.black;
  final Color shadowcolordark = Colors.grey[600];
  final String bpicdark = 'assets/10751-dark.jpg';
  final String bpiclight = 'assets/10751-light.jpg';


  bool boundingoverlay = true;
  bool aionoff = true;
  CameraController controller;
  List cameras;
  int selectedCameraIdx;
  String imagePath;
  bool isDetecting = false;
  bool cameraon = false;
  bool _hvisible = true;
  bool _dvisible = false;
  bool _svisible = false;
  int _pindex = 0;
  int _cindex = 0;
  int _imageHeight = 0;
  int _imageWidth = 0;
  bool darkswitch = true;
  String _mapstyle;
  String _dark;
  String _light;

  GoogleMapController mapController;
  VideoPlayerController _controller;
  TextEditingController sname = TextEditingController();
  LatLng _center = LatLng(13.0246398, 77.6544643);
  List<dynamic> _recognition;
  String _model = "";

  loadModel() async {
    String result;
    result = await Tflite.loadModel(
      model: "assets/ssd_mobilenet.tflite",
      labels: "assets/ssd_mobilenet.txt",
      useGpuDelegate: true,
    );
    print(result);
  }

  deloadModel() async {
    String result;
    result = await Tflite.close();
    print(result);
  }

  onSelectModel(model) {
    setState(() {
      _model = model;
    });
    loadModel();
  }

  setRecognitions(recognitions, imageHeight, imageWidth) {
    setState(() {
      _recognition = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  void initState() {
    super.initState();
    // 1
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.length > 0) {
        setState(() {
          // 2
          selectedCameraIdx = 0;
        });

        _initCameraController(cameras[selectedCameraIdx]).then((void v) {});
      } else {
        print("No camera available");
      }
    }).catchError((err) {
      // 3
      print('Error: $err.code\nError Message: $err.message');
    });
    rootBundle.loadString('assets/dark.txt').then((string) {_dark = string;});
    rootBundle.loadString('assets/light.txt').then((string) {_light = string;});
    intializesettings();
    //colorchange();
    _controller = VideoPlayerController.asset('assets/test1.mp4');
    _controller.setLooping(true);
  }

  Future _initCameraController(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(cameraDescription, ResolutionPreset.high);

    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }

      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      print(e);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget _cameraPreviewWidget() {
    recobox();
    var size = MediaQuery.of(context).size;
    //double aspect1 = size.height / size.width;
    double aspect2 = size.width / size.height;
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Loading',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.0,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspect2,
      child: CameraPreview(controller),
    );
  }

  recobox() {
    if (!_dvisible) {
      if (cameraon) controller.stopImageStream();
    } else {
      if (aionoff) {
        controller.startImageStream((CameraImage img) {
          if (!isDetecting) {
            cameraon = true;
            isDetecting = true;
            int startTime = new DateTime.now().millisecondsSinceEpoch;
            Tflite.detectObjectOnFrame(
                    bytesList: img.planes.map((plane) {
                      return plane.bytes;
                    }).toList(),
                    model: "SSDMobileNet",
                    imageHeight: img.height,
                    imageWidth: img.width,
                    imageMean: 127.5,
                    imageStd: 127.5,
                    numResultsPerClass: 1,
                    threshold: 0.4)
                .then((recognitions) {
              int endTime = new DateTime.now().millisecondsSinceEpoch;
              print("Detection took ${endTime - startTime}");
              setRecognitions(recognitions, img.height, img.width);
              isDetecting = false;
            });
          }
        });
      } else {
        controller.stopImageStream();
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(_mapstyle);
  }

  intializesettings() async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    darkswitch = prefs.getBool("darkonoff");
    colorchange();
  }

  toggleschange(String key,bool value) async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    print(prefs.getBool(key));
  }

  colorchange()
  {
    if(!darkswitch)
      {
        tcolor = textcolor;
        bcolor = backgroundcolor;
        scolor = shadowcolor;
        bpic = bpiclight;
        _mapstyle = _light;
        hiconcolor = _hvisible == true ? selected: unselected;
        siconcolor = _svisible == true ? selected : unselected;
        diconcolor = _dvisible == true ? selected : unselected;
      }
    else
      {
        tcolor = textcolordark;
        bcolor = backgroundcolordark;
        scolor = shadowcolordark;
        bpic = bpicdark;
        _mapstyle = _dark;
        hiconcolor = _hvisible == true ? selected: unselecteddark;
        siconcolor = _svisible == true ? selected : unselecteddark;
        diconcolor = _dvisible == true ? selected : unselecteddark;
      }
  }

  searchquery(String a) {}
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            IndexedStack(
              index: _cindex,
              children: [
                Stack(
                  children: [
                    Container(
                      height: size.height * 0.3,
                      width: 700,
                      decoration: BoxDecoration(
                          image: DecorationImage(
                        colorFilter: new ColorFilter.mode(
                            Colors.white.withOpacity(0.8), BlendMode.dstATop),
                        image: AssetImage(bpic),
                      )),
                    ),
                    SafeArea(
                      child: Column(
                        //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
                            child: Container(
                              height: size.height * 0.1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Material(
                                    elevation: 5,
                                    borderRadius: new BorderRadius.circular(20),
                                    child: Container(
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundImage:
                                            AssetImage('assets/User Icon.png'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                              child: Material(
                                color: Color(0x00000000),
                                elevation: 10,
                                shadowColor: Colors.grey[50],
                                child: Text(
                                  'Driver Assist',
                                  style: TextStyle(
                                    fontSize: 30.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: size.height * 0.03,
                          ),
                          Material(
                            elevation: 10,
                            shadowColor: scolor,
                            color: bcolor,
                            borderRadius: new BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                IndexedStack(
                                  index: _pindex,
                                  children: [
                                    AnimatedOpacity(
                                      opacity: _hvisible ? 1.0 : 0.0,
                                      duration: Duration(milliseconds: 500),
                                      child: Container(
                                        /*decoration: new BoxDecoration(
                              shape: BoxShape.rectangle,
                              border: new Border.all(color: Colors.black,width: 2.0),
                            ),*/
                                        child: SizedBox(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.75,
                                          child: Column(
                                            children: [
                                              Container(
                                                height: size.height * 0.08,
                                                child: Center(
                                                  child: Text(
                                                    'Home',
                                                    style: TextStyle(
                                                        fontSize: 16.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: tcolor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const Divider(
                                                  height: 5,
                                                  indent: 100,
                                                  endIndent: 100,
                                                  color: Colors.black),
                                              Container(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          4, 13, 4, 0),
                                                  child: SizedBox(
                                                    width: size.width * 0.95,
                                                    height: size.height * 0.3,
                                                    child: GoogleMap(
                                                      mapType: MapType.normal,
                                                      myLocationEnabled: true,
                                                      onMapCreated:
                                                          _onMapCreated,
                                                      initialCameraPosition:
                                                          CameraPosition(
                                                              target: _center,
                                                              zoom: 18),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          10, 10, 10, 0),
                                                  child: Material(
                                                    elevation: 0,
                                                    color: bcolor,
                                                    borderRadius:
                                                        new BorderRadius
                                                            .circular(25.0),
                                                    child: TextField(
                                                      controller: sname,
                                                      onSubmitted: searchquery(sname.text),
                                                      textAlign:TextAlign.center,
                                                      decoration: new InputDecoration(
                                                        labelText:'Enter Destination',
                                                        labelStyle: TextStyle(color: tcolor),
                                                        fillColor: tcolor,
                                                        border:new OutlineInputBorder(
                                                          borderRadius:new BorderRadius.circular(25.0),
                                                          borderSide: new BorderSide(
                                                            color: tcolor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          125, 50, 120, 8),
                                                  child: TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                        primary: Colors.black,
                                                        backgroundColor:
                                                            Colors.blue),
                                                    icon:
                                                        Icon(Icons.navigation),
                                                    label: Text('Start'),
                                                    onPressed: () {
                                                      print('Lets Start!');
                                                      sname.text == ""
                                                          // ignore: unnecessary_statements
                                                          ? ""
                                                          : MapsLauncher
                                                              .launchQuery(
                                                                  sname.text);
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    AnimatedOpacity(
                                      opacity: _svisible ? 1.0 : 0.0,
                                      duration: Duration(milliseconds: 500),
                                      child: Container(
                                        child: SizedBox(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.75,
                                          child: Column(
                                            children: [
                                              Container(
                                                height: size.height * 0.08,
                                                child: Center(
                                                  child: Text(
                                                    'Settings',
                                                    style: TextStyle(
                                                        fontSize: 16.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: tcolor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const Divider(
                                                  height: 5,
                                                  indent: 100,
                                                  endIndent: 100,
                                                  color: Colors.black),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 25),
                                                child: SingleChildScrollView(
                                                  child: Container(
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Container(
                                                              width:size.width*0.71,
                                                              child: Text("Dark mode",
                                                                style: TextStyle(
                                                                    fontWeight:FontWeight.bold,
                                                                    fontSize:14,
                                                                  color: tcolor,
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              child: Switch(
                                                                value:
                                                                    darkswitch,
                                                                activeColor:
                                                                    Colors.blue,
                                                                activeTrackColor:
                                                                    Colors.blue,
                                                                onChanged:
                                                                    (value) {
                                                                  setState(() {
                                                                    toggleschange("darkonoff", value);
                                                                    darkswitch = value;
                                                                    colorchange();
                                                                  });
                                                                },
                                                              ),
                                                            ),
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
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  height: size.height,
                  width: size.width,
                  //color: Colors.white,
                  child: AnimatedOpacity(
                      opacity: _dvisible ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 500),
                      child: _model == ""
                          ? Container()
                          : Stack(
                              children: [
                                _cameraPreviewWidget(),
                                boundingoverlay
                                    ? BoundingBox(
                                        _recognition == null
                                            ? []
                                            : _recognition,
                                        math.max(_imageHeight, _imageWidth),
                                        math.min(_imageHeight, _imageWidth),
                                        size.height,
                                        size.width,
                                        _model)
                                    : Container(),
                                AnimatedPositioned(
                                  top: size.height * 0.05,
                                  left: size.width * 0.3,
                                  duration: Duration(milliseconds: 500),
                                  child: Container(
                                    width: size.width * 0.4,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                            icon: Icon(Icons.auto_fix_high,
                                                color: boundingiconcolor),
                                            onPressed: aionoff
                                                ? () {
                                                    setState(() {
                                                      boundingoverlay =
                                                          !boundingoverlay;
                                                      if (boundingoverlay)
                                                        boundingiconcolor =
                                                            selected;
                                                      else
                                                        boundingiconcolor =
                                                            overlayunselected;
                                                    });
                                                  }
                                                : null),
                                        IconButton(
                                            icon: Image.asset(
                                                'assets/AIIcon.png',
                                                color: aiconcolor),
                                            disabledColor: Colors.grey,
                                            onPressed: () {
                                              setState(() {
                                                aionoff = !aionoff;
                                                if (aionoff)
                                                  aiconcolor = selected;
                                                else {
                                                  aiconcolor =
                                                      overlayunselected;
                                                }
                                                boundingoverlay = aionoff;
                                                if (boundingoverlay)
                                                  boundingiconcolor = selected;
                                                else {
                                                  boundingiconcolor =
                                                      overlayunselected;
                                                  boundingiconcolor =
                                                      overlaydisabled;
                                                }
                                              });
                                            }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )),
                ),
              ],
            ),
            Positioned(
              bottom: size.height * 0.03,
              left: size.width * 0.21,
              child: Container(
                width: size.width * 0.6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      elevation: 12,
                      borderRadius: new BorderRadius.circular(25),
                      shadowColor: scolor,
                      color: bcolor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(Icons.home, color: hiconcolor),
                            onPressed: () {
                              setState(() {
                                _hvisible = true;
                                _svisible = false;
                                _dvisible = false;
                                _pindex = 0;
                                _cindex = 0;
                                //hiconcolor = selected;
                                //siconcolor = unselected;
                                //diconcolor = unselected;
                              });
                              colorchange();
                            },
                          ),
                          IconButton(
                              icon: Icon(Icons.dashboard_customize,
                                  color: diconcolor),
                              onPressed: () {
                                setState(() {
                                  _hvisible = false;
                                  _svisible = false;
                                  _dvisible = true;
                                  _pindex = 0;
                                  _cindex = 1;
                                  onSelectModel(ssd);
                                });
                                colorchange();
                              }),
                          IconButton(
                              icon: Icon(Icons.settings, color: siconcolor),
                              onPressed: () {
                                setState(() {
                                  _hvisible = false;
                                  _svisible = true;
                                  _dvisible = false;
                                  _pindex = 1;
                                  _cindex = 0;
                                });
                                colorchange();
                              })
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
