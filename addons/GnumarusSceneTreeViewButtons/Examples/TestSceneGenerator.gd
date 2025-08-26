#class_name GnumarusSceneTreeViewButtonsTestSceneGenerator
extends Node2D



func _ready() -> void:
	var v_par: Node2D = Node2D.new()
	v_par.visible = false

	var v_cnt: int = 0
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", false, false, false)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", true, false, false)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", false, true, false)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", true, true, false)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", false, false, true)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", true, false, true)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", false, true, true)
	add_child_(v_par, ClassDB.instantiate("Node"), "Node", true, true, true)

	for i_native_class_name in ClassDB.get_class_list():
		if i_native_class_name == 'Node' or ClassDB.is_parent_class(i_native_class_name, 'Node'):
			if not ClassDB.can_instantiate(i_native_class_name):
				#print('cannot instantiate %s'%i_native_class_name)
				continue

			# var v_node: Node = ClassDB.instantiate(i_native_class_name)
			var v_with_con: bool = v_cnt % 2 == 0
			var v_with_meta: bool = v_cnt % 3 == 0
			add_child_(v_par, ClassDB.instantiate(i_native_class_name), i_native_class_name, false, v_with_con, v_with_meta)
			add_child_(v_par, ClassDB.instantiate(i_native_class_name), i_native_class_name+'DESCRIPTION', true, v_with_con, v_with_meta)
			v_cnt += 1

	var v_pack: PackedScene = PackedScene.new()
	v_pack.pack(v_par)
	get_script().resource_path.get_base_dir()
	ResourceSaver.save(v_pack, get_script().resource_path.get_base_dir()+'/SceneTreeViewButtonsTest.tscn')

	if not Engine.is_editor_hint():
		get_tree().quit()

	return



func add_child_(p_parent: Node, p_child: Node, p_name: String, p_with_description: bool, p_with_connection: bool, p_with_meta: bool) -> Node:
	p_parent.add_child(p_child)

	if is_instance_valid(p_parent.owner):
		p_child.owner = p_parent.owner

	else:
		p_child.owner = p_parent

	if p_with_description:
		p_child.editor_description = str(p_child)

	if p_with_connection:
		p_child.ready.connect(p_child.can_process, CONNECT_PERSIST)

	if p_with_meta:
		p_child.set_meta('some_meta', randi_range(0, 100))

	if not p_name.is_empty():
		p_child.name = p_name

	if 'visible' in p_child:
		p_child.visible = false

	return p_child
