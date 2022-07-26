import 'dart:collection';
import 'dart:io';
import 'package:mime/mime.dart';
import '../ServerUtils.dart';
import 'ServerRoute.dart';
import 'package:path/path.dart' as p;

class WebServer{
  InternetAddress _host = InternetAddress.anyIPv4;
  int _port = 8001;
  HttpServer? _server;
  List<String> filetypes = [];
  HashMap<String,ServerRoute> routes = HashMap();

  WebServer({host,port}){
    routes['/'] = ServerRoute(path:'/',handler:index,methods:['GET']);
    if(host!=null) _host = host;
    if(port!=null) _port=port;
  }

  Future<HttpServer?> _bindServer() async {
    if(this._server==null){      
      this._server = await HttpServer.bind(_host, _port,shared:true);
    }
    else
      print("Server already running on ${_host}:${_port}");
    return this._server;
  }

  addRoute({required ServerRoute route}){
    assert (!this.routes.containsKey(route.path),"Route $route.path already exists");
    routes[route.path] = route;
  }

  addFileType(String type)=>this.filetypes.add(type);

  index(HttpRequest request) async {
    File file = File.fromUri(Uri.file('qdot/static/index.html'));
    final data = await file.readAsString();
    request.response
      ..headers.contentType = ContentType.html
      ..write(data)
      ..close();
  }

  Future<dynamic> run() async {
    await _bindServer();
    ProcessSignal.sigint.watch().listen((event) {
      if(event==ProcessSignal.sigint) exit(0);
    });

    print("Running server on http://${_host.address}:$_port");

    try{
      if(this._server!=null){
        await for (HttpRequest request in this._server!) {
          try{
            await handleRequest(request);
          }catch(e){
            continue;
          }
        }
      }
    }catch(e,s){
      print(e);
      print(s);
    }
  }  

  handleRequest(HttpRequest request) async {
    final endpoint = Uri.parse(request.requestedUri.toString()).path;
    int statusCode;
    if(this.filetypes.contains(p.extension(endpoint).replaceFirst('.',''))){
      try{
        final path = endpoint.replaceFirst('/', '${Directory.current.path.replaceAll('\\','/')}/');
        File file = File.fromUri(Uri.file(path));
        final mimeType = lookupMimeType(path)!.split('/');
        request.response
          ..headers.contentType = ContentType(mimeType[0],mimeType[1])
          ..statusCode = 200;     
        file.openRead().pipe(request.response);           
        statusCode = 200;
      }catch(e,s){
        print(e);
        print(s);
        request.response
          ..statusCode = 500
          ..close();
        statusCode = 500;
        throw Exception;
      }
      print("${_host.address} - - [${ServerUtils.printDateTime()}] '${request.method} ${endpoint} HTTP/${request.protocolVersion}' $statusCode");
      return;
    }
    if(routes.keys.contains(endpoint)){
      statusCode = await routes[endpoint]!.call(request);
    }else{
      statusCode = 404;
    }
    print("${_host.address} - - [${ServerUtils.printDateTime()}] '${request.method} ${endpoint} HTTP/${request.protocolVersion}' $statusCode");
  }
}