#library("objectory_restful_connection");
#import("schema.dart");
#import("persistent_object.dart");
#import("objectory_query_builder.dart");
#import("objectory_base.dart");
#import("package:DartJsonClient/JsonClient.dart");

class ObjectoryDirectConnectionImpl extends ObjectoryBaseImpl{  
  JsonClient db;
  
  Future<bool> open(String uri){
    db = new JsonClient(uri);
    db.logLevel = LogLevel.All;
  }
  
  void save(RootPersistentObject persistentObject){
    //db.collection(persistentObject.type).save(persistentObject.map);
    db.post("/${persistentObject.type}/save/", persistentObject.map).then((response) {
      if (persistentObject.id === null) {
        persistentObject.id = response["createdId"];
        if (persistentObject.id === null) {
          throw 'Error! Mongo_dart_server did not return Object id after object insertion'; 
        }
        persistentObject.map["_id"] = persistentObject.id;
      }        
    });      
  }
  
  void remove(RootPersistentObject persistentObject){
    if (persistentObject.id === null){
      return;
    }
//    db.collection(persistentObject.type).remove({"_id":persistentObject.id});
    db.post("/${persistentObject.type}/remove/", {"_id":persistentObject.id});
  }
  
  Future<List<RootPersistentObject>> find(ObjectoryQueryBuilder selector){    
    Completer completer = new Completer();
    var result = new List<RootPersistentObject>();
    db.collection(selector.className)
      .find(selector.map)
      .each((map){
        RootPersistentObject obj = objectory.map2Object(selector.className,map);
        result.add(obj);
      }).then((_) => completer.complete(result));
    return completer.future;  
  }
  
  Future<RootPersistentObject> findOne(ObjectoryQueryBuilder selector){
    Completer completer = new Completer();
    var obj;
    if (selector.map.containsKey("_id")) {
      obj = findInCache(selector.map["_id"]);
    }
    if (obj !== null) {
      completer.complete(obj);
    }  
    else {
      db.collection(selector.className)
        .findOne(selector.map)
        .then((map){
          if (map === null) {
           completer.complete(null); 
          }
          else {
            obj = findInCache(map["_id"]);          
            if (obj === null) {
              if (map !== null) {
                obj = objectory.map2Object(selector.className,map);
                addToCache(obj);
                }              
              }
            completer.complete(obj);
          }              
        });
      }    
    return completer.future;  
  }
  
  Future<Map> dropDb(){
    return db.drop();
  }

  Future<Map> wait(){
    return db.wait();
  }


  void close(){
    db.close();
  }
  Future dropCollections() {
    List futures = [];
    schemata.forEach( (key, value) {
       if (value.isRoot) {
        futures.add(db.collection(key).drop());
       }
    });
    return Futures.wait(futures);
  }
}


Future<bool> setUpObjectory(String uri, Function registerClassCallback, [bool dropCollections = false]){
  var res = new Completer();
  objectory = new ObjectoryDirectConnectionImpl();
  objectory.open(uri).then((_){
      registerClassCallback();
      if (dropCollections) {
        objectory.dropCollections().then((_) =>  res.complete(true));
      }
      else
      {
        res.complete(true);
      }
  });    
  return res.future;
}