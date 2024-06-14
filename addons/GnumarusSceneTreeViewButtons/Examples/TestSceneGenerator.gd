extends Node2D


func _ready() -> void:
	var vpar:Node2D = Node2D.new()
	vpar.visible = false
	var v:Node
	var vcnt:int = 0
	for i in ClassDB.get_class_list():
		if i == 'Node' or ClassDB.is_parent_class(i, 'Node'):
			if not ClassDB.can_instantiate(i):
				#print('cannot instantiate %s'%i)
				continue
			v = ClassDB.instantiate(i)
			var vwithcon:bool = vcnt % 2 == 0
			add_child_(vpar, ClassDB.instantiate(i), i, false, vwithcon)
			add_child_(vpar, ClassDB.instantiate(i), i+'DESCRIPTION', true, vwithcon)
			vcnt += 1
	var vpack:PackedScene = PackedScene.new()
	vpack.pack(vpar)
	get_script().resource_path.get_base_dir()
	ResourceSaver.save(vpack, get_script().resource_path.get_base_dir()+'/SceneTreeViewButtonsTest.tscn')
	if not Engine.is_editor_hint():
		get_tree().quit()
	return


func add_child_(pparent:Node, pchild:Node, pname:String, pwithdescription:bool, pwithconnection:bool) -> Node:
	pparent.add_child(pchild)
	if is_instance_valid(pparent.owner):
		pchild.owner = pparent.owner
	else:
		pchild.owner = pparent
	if pwithdescription:
		pchild.editor_description = str(pchild)
	if pwithconnection:
		pchild.ready.connect(pchild.can_process, CONNECT_PERSIST)
	if not pname.is_empty():
		pchild.name = pname
	if 'visible' in pchild:
		pchild.visible = false
	return pchild
