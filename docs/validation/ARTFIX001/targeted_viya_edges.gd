extends SceneTree
var checks:int=0
var failures:Array[String]=[]
func _initialize()->void:
    var test=load("res://tests/test_viya_edges.gd")
    test.run(Callable(self,"verify"))
    print(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
func verify(condition:bool,message:String)->void:
    checks+=1
    if not condition:failures.append(message)
