#class_name GnumarusSceneTreeViewButtonsEditorPluginHelper
@tool
extends RefCounted

# THERE IS A KNOWN BUG in which the editor removes the added buttons for no reason. the only workaround for now is changing the edited scene and go back to the previous

class TreeItemInfo extends RefCounted:
	var m_btns_ids: Dictionary  #[String, int]
	var m_tree_item: TreeItem
	var m_nodepath: NodePath
	var m_node: Node


const S_DEBUG_VERBOSE: bool = true
const S_IGNORE_CONNECTIONS_TO_NATIVE_METHODS: bool = false


var TreeItemHelper: GDScript

var m_description_btn_tex: Texture2D
var m_incoming_connections_btn_tex: Texture2D
var m_metas_btn_tex: Texture2D

var m_edited_scene_tree_tree: Tree

var m_addon_dir: String
var m_items_to_btn_map: Dictionary  #[TreeItem, TreeItemInfo]
var m_last_check_time_ms: int = -999999
var m_last_edited_scene = null



func _init() -> void:
	_print("_init()", "\n")
	m_addon_dir = get_script().resource_path.get_base_dir()
	TreeItemHelper = load(m_addon_dir + "/TreeItemHelper.gd")
	m_description_btn_tex = load(m_addon_dir + "/EditorCommentSceneTreeViewIcon.svg")
	m_incoming_connections_btn_tex = load(m_addon_dir + "/IncomingConnectionsSceneTreeViewIcon.svg")
	m_metas_btn_tex = load(m_addon_dir + "/MetasSceneTreeViewIcon.svg")
	m_items_to_btn_map = {}



func _print(p_after: Variant, p_before: Variant = "") -> void:
	print("%s- GnumarusSceneTreeViewButtonsEditorPluginHelper: %s" % [p_before, p_after])



func on_scene_view_tree_rebuilt():
	_print("on_scene_view_tree_rebuilt()")
	var v_low_processor_usage_mode: bool = OS.low_processor_usage_mode
	#OS.low_processor_usage_mode = false # uso de CPU fica muito alto, 20%

	# waiting some frames since the previous tree predelete is called BEFORE the tree is deleted
	while is_instance_valid(m_edited_scene_tree_tree):
		await Engine.get_main_loop().process_frame

	OS.low_processor_usage_mode = v_low_processor_usage_mode
	setup()



func update():
	var v_now_ms: int = Time.get_ticks_msec()
	var v_cur_edited_scene: Node = Engine.get_main_loop().edited_scene_root

	if v_cur_edited_scene != m_last_edited_scene:
		m_last_check_time_ms = v_now_ms
		_print('edited scene changed to %s (%s). setting up again' % [v_cur_edited_scene.get_instance_id(), v_cur_edited_scene.scene_file_path])
		setup()

	else:
		var v_diff_ms: int = v_now_ms - m_last_check_time_ms

		if v_diff_ms < 1_000:
			return

		m_last_check_time_ms = v_now_ms
		#_print('setup because time passed')
		setup()



func setup():
	#print('setup')
	var v_editor_root_window: Window = Engine.get_main_loop().root

	if not is_instance_valid(m_edited_scene_tree_tree):
		#_print('edited scene tree tree is invalid')
		m_edited_scene_tree_tree = get_scene_tree_view_tree_control()

	if not is_instance_valid(m_edited_scene_tree_tree):
		#_print('couldnt find scene tree view')
		return

	if not m_edited_scene_tree_tree.button_clicked.is_connected(on_button_clicked):
		#_print('button clicked not connected')
		m_edited_scene_tree_tree.button_clicked.connect(on_button_clicked)

	var v_scene_tree_item: TreeItem = m_edited_scene_tree_tree.get_root()

	if not is_instance_valid(v_scene_tree_item):
		#_print('edited scene tree tree root is invalid')
		# can be invalid uppon opening the editor the fist time
		return

	var V_COLUMN_IDX: int = v_scene_tree_item.get_tree().columns - 1 # should be 0
	m_last_edited_scene = v_editor_root_window.get_node(v_scene_tree_item.get_metadata(V_COLUMN_IDX))
	# only parse the tree a single time
	#if v_scene_tree_item.get_script() == TreeItemHelper:
		#_print('edited scene tree tree root already is scripted')
		#return
	clean_invalid_tree_items()
	v_scene_tree_item.set_script(TreeItemHelper)
	#TODO continue from here
	# predelete.connect() won't work for unknow reasons, it says it cant find connect() on Signal

	if not v_scene_tree_item.is_connected("predelete", on_scene_view_tree_rebuilt):
		#_print('connecting predelete')
		v_scene_tree_item.connect("predelete", on_scene_view_tree_rebuilt)

	var m_next_btn_id: int = 100  # 2147483647
	const V_INC: int = +1  # -1

	#_print('before tree item loop')
	while is_instance_valid(v_scene_tree_item):
		var v_node_path: NodePath = v_scene_tree_item.get_metadata(V_COLUMN_IDX) as NodePath
		var v_node_path_str: String = str(v_node_path)
		var v_is_debugged_nodepath: bool = v_node_path_str.ends_with('MainCharacter')
		#if v_is_debugged_nodepath:#DELETEME
			#print('')#DELETEME
		var v_node: Node = v_editor_root_window.get_node(v_node_path)
		var v_btn_count: int = v_scene_tree_item.get_button_count(V_COLUMN_IDX)
		#if v_is_debugged_nodepath:#DELETEME
			#print(v_btn_count)#DELETEME
			#print(v_scene_tree_item.get_instance_id())
			#if v_btn_count == 4:
				#if not v_scene_tree_item.has_meta('debug'):
					#print('does not have debug meta')
					#v_scene_tree_item.set_meta('debug', true)

		var v_has_description_txt: bool = v_node.editor_description.length() > 0
		var v_has_incoming_connections: bool = v_node.get_incoming_connections().filter(connection_filter).size() > 0
		var v_has_meta: bool = v_node.get_meta_list().filter(meta_filter).size() > 0

		var v_has_description_btn: bool = false
		var v_description_btn_idx: int = -1

		var v_has_incoming_connections_btn: bool = false
		var v_incoming_connections_btn_idx: int = -1

		var v_has_meta_btn: bool = false
		var v_meta_btn_idx: int = -1

		#_print('before btn idx loop')
		for i_btn_idx in v_scene_tree_item.get_button_count(V_COLUMN_IDX):
			var v_btn_tooltip: String = v_scene_tree_item.get_button_tooltip_text(V_COLUMN_IDX, i_btn_idx)

			match v_btn_tooltip:
				"editor_description":
					v_has_description_btn = true
					v_description_btn_idx = i_btn_idx

				"incoming_connections":
					v_has_incoming_connections_btn = true
					v_incoming_connections_btn_idx = i_btn_idx

				"metas":
					v_has_meta_btn = true
					v_meta_btn_idx = i_btn_idx

		var v_tree_item_info: TreeItemInfo = m_items_to_btn_map.get(v_scene_tree_item, null)

		if not is_instance_valid(v_tree_item_info):
			#_print('tree item info is invalid')
			v_tree_item_info = TreeItemInfo.new()
			m_items_to_btn_map[v_scene_tree_item] = v_tree_item_info
			v_tree_item_info.m_btns_ids = {}
			v_tree_item_info.m_tree_item = v_scene_tree_item
			v_tree_item_info.m_nodepath = v_node_path
			v_tree_item_info.m_node = v_node

		# DESCRIPTION BUTTON
		if v_has_description_btn:
			if not v_has_description_txt: # erase description button if needed
				#print('erasing description btn')
				# get_button_by_id is just not working as expected, so I'm getting the button index back there
				#var v_btn_idx: int = v_scene_tree_item.get_button_by_id(V_COLUMN_IDX, v_tree_item_info.m_btns_ids.get('editor_description', -1))
				v_scene_tree_item.erase_button(V_COLUMN_IDX, v_description_btn_idx)

		else:
			if v_has_description_txt: # add description button if needed
				#print('adding description btn')
				while v_scene_tree_item.get_button_by_id(V_COLUMN_IDX, m_next_btn_id) >= 0: # get_button_by_id returns -1 for inexisting ids
					m_next_btn_id += V_INC

				v_tree_item_info.m_btns_ids.editor_description = m_next_btn_id
				v_scene_tree_item.add_button(
					V_COLUMN_IDX, m_description_btn_tex, m_next_btn_id, false, "editor_description"
				)
				m_next_btn_id += V_INC

		# INCOMMING CONNECTIONS BUTTON
		if v_has_incoming_connections_btn:
			if not v_has_incoming_connections: # erase incoming connections button if needed
				v_scene_tree_item.erase_button(V_COLUMN_IDX, v_incoming_connections_btn_idx)

		else:
			if v_has_incoming_connections: # add incoming connections button if needed
				while v_scene_tree_item.get_button_by_id(V_COLUMN_IDX, m_next_btn_id) >= 0:
					m_next_btn_id += V_INC

				v_tree_item_info.m_btns_ids.incoming_connections = m_next_btn_id
				v_scene_tree_item.add_button(
					V_COLUMN_IDX, m_incoming_connections_btn_tex, m_next_btn_id, false, "incoming_connections"
				)
				m_next_btn_id += V_INC

		# METAS BUTTON
		if v_has_meta_btn:
			if not v_has_meta: # erase metas button if needed
				v_scene_tree_item.erase_button(V_COLUMN_IDX, v_meta_btn_idx)

		else:
			if v_has_meta: # add metas button if needed
				while v_scene_tree_item.get_button_by_id(V_COLUMN_IDX, m_next_btn_id) >= 0:
					m_next_btn_id += V_INC

				v_tree_item_info.m_btns_ids.metas = m_next_btn_id
				v_scene_tree_item.add_button(
					V_COLUMN_IDX, m_metas_btn_tex, m_next_btn_id, false, "metas"
				)
				m_next_btn_id += V_INC
			# end for loop

		v_scene_tree_item = v_scene_tree_item.get_next_visible()
	# end while loop
# end setup func



func meta_filter(p_meta_name: String) -> bool:
	match p_meta_name:
		"_menu_name":
			return false

		"_edit_lock_":
			return false

		"_edit_group_":
			return false

		"_custom_type_script":
			return false

		"_aseprite_wizard_interface_config_":
			# from the aseprite AsepriteWizard addon
			return false

	return true



func on_editor_description_clicked(p_tree_item_info: TreeItemInfo):
	var v_node: Node = p_tree_item_info.m_node
	var v_last: TreeItem = m_edited_scene_tree_tree.get_selected()
	var v_was_same: bool = v_last == p_tree_item_info.m_tree_item
	m_edited_scene_tree_tree.set_selected(p_tree_item_info.m_tree_item, 0)

	if not v_was_same:
		var v_low_processor_usage_mode: bool = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = false

		for i_proc_frame in 10: # HACK: TODO: find proper way of telling that the editor has updated and only proceed after update
			await Engine.get_main_loop().process_frame

		OS.low_processor_usage_mode = v_low_processor_usage_mode

	var v_editor_description_btn: Node = get_editor_description_button()
	v_editor_description_btn.pressed.emit()



func _alert(p_text: String, p_title: String = "Message") -> void:
	var v_diag: AcceptDialog = AcceptDialog.new()
	v_diag.dialog_text = p_text
	v_diag.title = p_title
	v_diag.close_requested.connect(v_diag.queue_free)
	# do not block input to the main window but let the alert always on top so that the user may search the signal emitters while keeping the modal open for reading the node path
	#v_diag.exclusive = false
	v_diag.always_on_top = true

	EditorInterface.get_base_control().add_child(v_diag)
	v_diag.popup_centered()



func on_metas_clicked(p_tree_item_info: TreeItemInfo):
	var v_node = p_tree_item_info.m_node
	var v_scene_root: Node = v_node.owner

	if not is_instance_valid(v_scene_root):
		v_scene_root = v_node

	var v_node_path_from_scene_root = str(v_scene_root.get_path_to(v_node))

	if v_node_path_from_scene_root == '.':
		v_node_path_from_scene_root += ' (%s)'%v_node.name

	var v_dict: Dictionary = {}

	for i_meta_name: String in v_node.get_meta_list().filter(meta_filter):
		v_dict[i_meta_name] = v_node.get_meta(i_meta_name)

	var v_msg: String = "metas for %s\n%s\n"%[v_node_path_from_scene_root, v_dict]
	_print(v_msg)
	_alert(v_msg, "metas for %s" % v_node_path_from_scene_root)



func on_incoming_connections_clicked(p_tree_item_info: TreeItemInfo):
	var v_node = p_tree_item_info.m_node
	var v_scene_root: Node = v_node.owner

	if not is_instance_valid(v_scene_root):
		v_scene_root = v_node

	var v_node_path_from_scene_root = v_scene_root.get_path_to(v_node)
	var v_cons_info = p_tree_item_info.m_node.get_incoming_connections().filter(connection_filter)

	var v_msg: String = (
		'\n%s has the following "%s" incom_ming node connections\n'
		% [v_node_path_from_scene_root, v_cons_info.size()]
	)

	for i_con_info: Dictionary in v_cons_info:
		var v_sig: Signal = i_con_info.signal
		var v_met: Callable = i_con_info.callable
		var v_emiter: Object = v_sig.get_object()
		var v_sig_path: String = "signal %s.%s" % [v_scene_root.get_path_to(v_emiter), v_sig.get_name()]
		var v_met_path: String = (
			"method %s.%s"
			% [v_scene_root.get_path_to(v_met.get_object()), i_con_info.callable.get_method()]
		)
		v_msg += "  %s\n  %s\n\n" % [v_sig_path, v_met_path]
		#_print(' %s\n %s\n'%[v_sig_path, v_met_path])
		#_print('if v_sig_name == "%s" and v_met_name == "%s": return false'%[v_sig.get_name(), i_con_info.callable.get_method()])

	v_msg += "\n"
	_print(v_msg)
	_alert(v_msg, "Incoming Connections for %s" % v_node_path_from_scene_root)



func on_button_clicked(
	p_item: Variant,
	p_column_idx: int,
	p_btn_id: int,
	p_mouse_button_index: int
) -> void:
	# if I type p_item as TreeItem sometimes I get "core/object/object.cpp:1140 - Error calling from signal 'button_clicked' to callable: 'RefCounted(EditorPluginHelper.gd)::on_button_clicked': Cannot convert argument 1 from Object to Object." when p_item is a freed instance. so instead I'm letting it untyped and asserting for it being null/freed OR being of the correct type
	assert(not is_instance_valid(p_item) or p_item is TreeItem)
	_print("p_item:%s; p_column_idx:%s; p_btn_id:%s; p_mouse_button_index:%s" % [p_item, p_column_idx, p_btn_id, p_mouse_button_index])

	if not is_instance_valid(p_item):
		return

	if not p_item in m_items_to_btn_map:
		# unmaped tree item
		return

	var v_tree_item_info: TreeItemInfo = m_items_to_btn_map[p_item]

	if v_tree_item_info.m_tree_item != p_item:
		# this should be impossible, but let's just play safe
		return

	for i_btn_tooltip in v_tree_item_info.m_btns_ids:
		match i_btn_tooltip:
			"editor_description":
				if p_btn_id == v_tree_item_info.m_btns_ids.editor_description:
					on_editor_description_clicked(v_tree_item_info)

			"incoming_connections":
				if p_btn_id == v_tree_item_info.m_btns_ids.incoming_connections:
					on_incoming_connections_clicked(v_tree_item_info)

			"metas":
				if p_btn_id == v_tree_item_info.m_btns_ids.metas:
					on_metas_clicked(v_tree_item_info)

	clean_invalid_tree_items()



func clean_invalid_tree_items():
	for i_item in m_items_to_btn_map: # TreeItem loop. I cannot type hint here otherwise will span the "Trying to assign invalid previously freed instance" error just for trying to loop a key I already know may be invalid
		if not is_instance_valid(i_item):
			#_print('cleaning invalid item')
			m_items_to_btn_map.erase(i_item)



var m_get_scene_tree_view_tree_control_cache:Tree
func get_scene_tree_view_tree_control() -> Tree:
	# diferent from, say, the inspector, which has a editor interface getter (EditorInterface.get_inspector()) there is no getter for the SceneTreeDock which even has a properly named node "Scene"
	if not is_instance_valid(m_get_scene_tree_view_tree_control_cache):
		m_get_scene_tree_view_tree_control_cache = get_node_robust(
			Engine.get_main_loop().root,
			[
				#name childindex nativeclass classname forwardsearch skipcount
				["@EditorNode@21272", 0, null, "EditorNode", true, 0],
				["@Panel@14", 4, Panel, "Panel", true, 0],
				["@VBoxContainer@15", 0, VBoxContainer, "VBoxContainer", true, 0],
				["DockHSplitLeftL", 1, null, "DockSplitContainer", true, 0],
				["DockHSplitLeftR", 1, null, "DockSplitContainer", true, 0],
				["DockVSplitLeftR", 0, null, "DockSplitContainer", true, 0],
				["DockSlotLeftUR", 0, TabContainer, "TabContainer", true, 0],
				["Scene", 1, null, "SceneTreeDock", true, 0],
				["@SceneTreeEditor@5134", 3, null, "SceneTreeEditor", true, 0],
				["@Tree@5105", 0, Tree, "Tree", true, 0],
			]
		)

		if not is_instance_valid(m_get_scene_tree_view_tree_control_cache):
			printerr("could not find scene tree inspector")

	return m_get_scene_tree_view_tree_control_cache



func get_editor_description_button() -> Button:
	# TODO: instead of Engine.get_main_loop().root, use EditorInterface.get_inspector() and search from there with a much shorter path
	var v_node = get_node_robust(
		EditorInterface.get_inspector(),
		[
			#name childindex nativeclass classname forwardsearch skipcount
			["@VBoxContainer@5440", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@EditorInspectorSection@22022", -2, null, "EditorInspectorSection", false, 1],
			["@VBoxContainer@22023", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@EditorPropertyMultilineText@22032", 0, null, "EditorPropertyMultilineText", true, 0],
			["@HBoxContainer@22024", 0, HBoxContainer, "HBoxContainer", true, 0],
			["@Button@22031", -1, Button, "Button", false, 0]
		]
	)

	if not is_instance_valid(v_node):
		_print("trying again")
		v_node = get_node_robust(
		EditorInterface.get_inspector(),
		[
			#name childindex nativeclass classname forwardsearch skipcount
			["@VBoxContainer@5440", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@EditorInspectorSection@22022", -2, null, "EditorInspectorSection", false, 0],
			["@VBoxContainer@22023", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@EditorPropertyMultilineText@22032", 0, null, "EditorPropertyMultilineText", true, 0],
			["@HBoxContainer@22024", 0, HBoxContainer, "HBoxContainer", true, 0],
			["@Button@22031", -1, Button, "Button", false, 0]
		]
	)

	return v_node



func type_check(p_node: Node, p_native_class: Variant, p_class_name: String) -> Node:
	# if found by name, validate the node type
	var v_found: bool = true

	# and check
	if is_instance_valid(p_native_class) and not is_instance_of(p_node, p_native_class):
		v_found = false

	if (
		v_found
		and not p_class_name.is_empty()
		and not ClassDB.is_parent_class(p_node.get_class(), p_class_name)
	):
		v_found = false

	if v_found:
		return p_node

	return null



## there is absolutely no guarantee that the editor node names and child node index will keep the same while using diferent versions of godot or even while using the editor. We can never expect that a simple nodepath will continue working. so instead of using simple nodepaths I'm using a path composed of arguments for searching each children step by step using several fallbacks (name, then index, then searching the nth node whose type matches. It is still not guarateed to work, but at least it is sligtly better than a plain nodepath search
func get_node_robust(p_root: Node, p_path: Array) -> Node:
	# TODO: maybe implement backtracking. if the search down a path was'nt suceeded, backtrack the parent and try again
	var v_current: Node = p_root
	var v_type_check_func: Callable = type_check

	for i_path_step_idx in p_path.size():
		var v_params: Array = p_path[i_path_step_idx]
		var v_name: String = v_params[0]
		var v_child_idx: int = v_params[1]
		var v_native_class: Variant = v_params[2]
		var v_class_name: String = v_params[3]
		var v_forward_search: bool = v_params[4]
		var v_skips: int = v_params[5]
		var v_next: Node

		# first, try to get the node by name
		v_next = v_current.get_node_or_null(v_name)
		if is_instance_valid(v_next):
			v_next = v_type_check_func.call(v_next, v_native_class, v_class_name)

			if is_instance_valid(v_next):
				v_current = v_next

				if S_DEBUG_VERBOSE:
					_print("found path step by name: %s, %s" % [i_path_step_idx, v_name])

				continue

		# TODO: instead of using a single index, have two indexes, one from the start and one from the end
		# if couldnt find it by type, find by index
		if absi(v_child_idx) < 100:
			if v_child_idx < v_current.get_child_count() and v_child_idx >= -v_current.get_child_count():
				v_next = v_current.get_child(v_child_idx)

			v_next = v_type_check_func.call(v_next, v_native_class, v_class_name)

			if is_instance_valid(v_next):
				v_current = v_next

				if S_DEBUG_VERBOSE:
					_print("found path step by index: %s, %s" % [i_path_step_idx, v_name])

				continue

		# if search by name didn't worked, iterate all children and search by type
		var v_rem_skips: int = v_skips

		if v_forward_search:
			for i_fwd_idx in v_current.get_child_count():
				var v_child = v_current.get_child(i_fwd_idx)

				if is_instance_valid(v_native_class) and not is_instance_of(v_child, v_native_class):
					#_print('wrong nativeclass. expected %s got %s'%[v_class_name, v_child.get_class()])
					if i_fwd_idx == v_current.get_child_count() - 1:
						if S_DEBUG_VERBOSE:
							_print("no more children")

					continue

				if (
					not v_class_name.is_empty()
					and not ClassDB.is_parent_class(v_child.get_class(), v_class_name)
				):
					if S_DEBUG_VERBOSE:
						_print("wrong classname %s, %s" % [v_class_name, v_child.get_class()])

					if i_fwd_idx == v_current.get_child_count() - 1:
						if S_DEBUG_VERBOSE:
							_print("no more children")

					continue

				if v_rem_skips <= 0:
					v_next = v_child

					if S_DEBUG_VERBOSE:
						_print(
							(
								"found path step by type with forward search and %s skips: %s, expected %s, got %s"
								% [v_skips, i_path_step_idx, v_name, v_next.name]
							)
						)

					break

				else:
					v_rem_skips -= 1
					if i_fwd_idx == v_current.get_child_count() - 1:
						if S_DEBUG_VERBOSE:
							_print("no more children")

		else:
			for i_back_idx in range(v_current.get_child_count() - 1, -1, -1):
				var v_child = v_current.get_child(i_back_idx)
				if is_instance_valid(v_native_class) and not is_instance_of(v_child, v_native_class):
					continue

				if (
					not v_class_name.is_empty()
					and not ClassDB.is_parent_class(v_child.get_class(), v_class_name)
				):
					continue

				if v_rem_skips <= 0:
					v_next = v_child

					if S_DEBUG_VERBOSE:
						_print(
							(
								"found path step by type with backwards search and %s skips: %s, expected %s, got %s"
								% [v_skips, i_path_step_idx, v_name, v_next.name]
							)
						)

					break

				else:
					v_rem_skips -= 1

		if is_instance_valid(v_next):
			v_current = v_next

		else:
			if S_DEBUG_VERBOSE:
				_print('failed at step "%s" of path (%s)' % [i_path_step_idx, v_params])

			return null

	return v_current



func connection_filter(p_dictionary: Dictionary) -> bool:
	var v_sig: Signal = p_dictionary.signal
	var v_signaler: Object = v_sig.get_object()

	if not v_signaler is Node:
		return false

	var v_met: Callable = p_dictionary.callable
	var v_met_name: String = v_met.get_method()

	if S_IGNORE_CONNECTIONS_TO_NATIVE_METHODS and "::" in v_met_name:
		return false

	var v_met_obj: Object = v_met.get_object()
	var v_sig_name: String = v_sig.get_name()

	if v_met_obj is CanvasItem:
		if (
			v_signaler == v_met_obj.get_parent()
			and (v_sig_name == "item_rect_changed"
			or v_sig_name == "size_changed")
			and v_met_name == "Control::_size_changed"
		):
			return false

	if v_met_obj is Container:
		if v_sig_name == "size_flags_changed" and v_met_name == "Container::queue_sort": return false
		if v_sig_name == "minimum_size_changed" and v_met_name == "Container::_child_minsize_changed": return false
		if v_sig_name == "visibility_changed" and v_met_name == "Container::_child_minsize_changed": return false
	if v_met_obj is Camera3D:
		if v_sig_name == "size_changed" and v_met_name == "Camera3D::update_gizmos": return false
	if v_met_obj is Tree:
		if v_sig_name == "timeout" and v_met_name == "Tree::_range_click_timeout": return false
		if v_sig_name == "value_changed" and v_met_name == "Tree::_scroll_moved": return false
		if v_sig_name == "text_submitted" and v_met_name == "Tree::_line_editor_submit": return false
		if v_sig_name == "gui_input" and v_met_name == "Tree::_text_editor_gui_input": return false
		if v_sig_name == "popup_hide" and v_met_name == "Tree::_text_editor_popup_modal_close": return false
		if v_sig_name == "id_pressed" and v_met_name == "Tree::popup_select": return false
		if v_sig_name == "value_changed" and v_met_name == "Tree::value_editor_changed": return false
	if v_met_obj is TextEdit:
		if v_sig_name == "value_changed" and v_met_name == "TextEdit::_scroll_moved": return false
		if v_sig_name == "scrolling" and v_met_name == "TextEdit::_v_scroll_input": return false
		if v_sig_name == "timeout" and v_met_name == "TextEdit::_toggle_draw_caret": return false
		if v_sig_name == "timeout" and v_met_name == "TextEdit::_click_selection_held": return false
		if v_sig_name == "timeout" and v_met_name == "TextEdit::_push_current_op": return false
	if v_met_obj is TabContainer:
		if v_sig_name == "tab_changed" and v_met_name == "TabContainer::_on_tab_changed": return false
		if v_sig_name == "tab_clicked" and v_met_name == "TabContainer::_on_tab_clicked": return false
		if v_sig_name == "tab_hovered" and v_met_name == "TabContainer::_on_tab_hovered": return false
		if v_sig_name == "tab_selected" and v_met_name == "TabContainer::_on_tab_selected": return false
		if v_sig_name == "tab_button_pressed" and v_met_name == "TabContainer::_on_tab_button_pressed": return false
		if v_sig_name == "active_tab_rearranged" and v_met_name == "TabContainer::_on_active_tab_rearranged": return false
		if v_sig_name == "mouse_exited" and v_met_name == "TabContainer::_on_mouse_exited": return false
		if v_sig_name == "renamed" and v_met_name == "TabContainer::_refresh_tab_names": return false

	if v_met_obj is TabBar:
		if v_sig_name == "mouse_exited" and v_met_name == "TabBar::_on_mouse_exited": return false
	if v_met_obj is SpinBox:
		if v_sig_name == "text_submitted" and v_met_name == "SpinBox::_text_submitted": return false
		if v_sig_name == "focus_entered" and v_met_name == "SpinBox::_line_edit_focus_enter": return false
		if v_sig_name == "focus_exited" and v_met_name == "SpinBox::_line_edit_focus_exit": return false
		if v_sig_name == "gui_input" and v_met_name == "SpinBox::_line_edit_input": return false
		if v_sig_name == "timeout" and v_met_name == "SpinBox::_range_click_timeout": return false
	if v_met_obj is ScrollContainer:
		if v_sig_name == "value_changed" and v_met_name == "ScrollContainer::_scroll_moved": return false
		if v_sig_name == "gui_focus_changed" and v_met_name == "ScrollContainer::_gui_focus_changed": return false
	if v_met_obj is RichTextLabel:
		if v_sig_name == "value_changed" and v_met_name == "RichTextLabel::_scroll_changed": return false
	if v_met_obj is Viewport:
		if v_sig_name == "child_order_changed" and v_met_name == "Viewport::gui_set_root_order_dirty": return false
		if v_sig_name == "child_order_changed" and v_met_name == "Viewport::canvas_parent_mark_dirty": return false
	if v_met_obj is PopupMenu:
		if v_sig_name == "draw" and v_met_name == "PopupMenu::_draw_background": return false
		if v_sig_name == "draw" and v_met_name == "PopupMenu::_draw_items": return false
		if v_sig_name == "window_input" and v_met_name == "PopupMenu::gui_input": return false
		if v_sig_name == "timeout" and v_met_name == "PopupMenu::_submenu_timeout": return false
		if v_sig_name == "timeout" and v_met_name == "PopupMenu::_minimum_lifetime_timeout": return false
	if v_met_obj is Popup:
		if v_sig_name == "window_input" and v_met_name == "Popup::_input_from_window": return false
	if v_met_obj is PathFollow2D:
		if v_sig_name == "timeout" and v_met_name == "PathFollow2D::_update_transform": return false
	if v_met_obj is BaseButton:
		if v_sig_name == "popup_hide" and v_met_name == "BaseButton::set_pressed": return false
	if v_met_obj is OptionButton:
		if v_sig_name == "index_pressed" and v_met_name == "OptionButton::_selected": return false
		if v_sig_name == "id_focused" and v_met_name == "OptionButton::_focused": return false
	if v_met_obj is MenuBar:
		pass
		if v_sig_name == "renamed" and v_met_name == "MenuBar::_refresh_menu_names": return false
		if v_sig_name == "about_to_popup" and v_met_name == "MenuBar::_popup_visibility_changed": return false
		if v_sig_name == "popup_hide" and v_met_name == "MenuBar::_popup_visibility_changed": return false
	if v_met_obj is MenuButton:
		if v_sig_name == "about_to_popup" and v_met_name == "MenuButton::_popup_visibility_changed": return false
		if v_sig_name == "popup_hide" and v_met_name == "MenuButton::_popup_visibility_changed": return false
	if v_met_obj is Label3D:
		if v_sig_name == "size_changed" and v_met_name == "Label3D::_font_changed": return false
	if v_met_obj is ItemList:
		if v_sig_name == "value_changed" and v_met_name == "ItemList::_scroll_changed": return false
		if v_sig_name == "mouse_exited" and v_met_name == "ItemList::_mouse_exited": return false
	if v_met_obj is HTTPRequest:
		if v_sig_name == "timeout" and v_met_name == "HTTPRequest::_timeout": return false
	if v_met_obj is GraphEdit:
		if v_sig_name == "draw" and v_met_name == "GraphEdit::_top_layer_draw": return false
		if v_sig_name == "gui_input" and v_met_name == "GraphEdit::_top_layer_input": return false
		if v_sig_name == "draw" and v_met_name == "GraphEdit::_connections_layer_draw": return false
		if v_sig_name == "value_changed" and v_met_name == "GraphEdit::_scroll_moved": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::_zoom_minus": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::_zoom_reset": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::_zoom_plus": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::_show_grid_toggled": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::_snapping_toggled": return false
		if v_sig_name == "value_changed" and v_met_name == "GraphEdit::_snapping_distance_changed": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::_minimap_toggled": return false
		if v_sig_name == "pressed" and v_met_name == "GraphEdit::arrange_nodes": return false
		if v_sig_name == "draw" and v_met_name == "GraphEdit::_minimap_draw": return false
	if v_met_obj is FileDialog:
		if v_sig_name == "pressed" and v_met_name == "FileDialog::_go_back": return false
		if v_sig_name == "pressed" and v_met_name == "FileDialog::_go_forward": return false
		if v_sig_name == "pressed" and v_met_name == "FileDialog::_go_up": return false
		if v_sig_name == "item_selected" and v_met_name == "FileDialog::_select_drive": return false
		if v_sig_name == "pressed" and v_met_name == "FileDialog::update_file_list": return false
		if v_sig_name == "toggled" and v_met_name == "FileDialog::set_show_hidden_files": return false
		if v_sig_name == "pressed" and v_met_name == "FileDialog::_make_dir": return false
		if v_sig_name == "confirmed" and v_met_name == "FileDialog::_action_pressed": return false
		if v_sig_name == "multi_selected" and v_met_name == "FileDialog::_tree_multi_selected": return false
		if v_sig_name == "cell_selected" and v_met_name == "FileDialog::_tree_selected": return false
		if v_sig_name == "item_activated" and v_met_name == "FileDialog::_tree_item_activated": return false
		if v_sig_name == "nothing_selected" and v_met_name == "FileDialog::deselect_all": return false
		if v_sig_name == "text_submitted" and v_met_name == "FileDialog::_dir_submitted": return false
		if v_sig_name == "text_submitted" and v_met_name == "FileDialog::_file_submitted": return false
		if v_sig_name == "item_selected" and v_met_name == "FileDialog::_filter_selected": return false
		if v_sig_name == "confirmed" and v_met_name == "FileDialog::_save_confirm_pressed": return false
		if v_sig_name == "confirmed" and v_met_name == "FileDialog::_make_dir_confirm": return false
	if v_met_obj is ColorPicker:
		if v_sig_name == "draw"and v_met_name == "ColorPicker::_hsv_draw": return false
		if v_sig_name == "pressed" and v_met_name == "ColorPicker::_pick_button_pressed" : return false
		if v_sig_name == "gui_input" and v_met_name == "ColorPicker::_sample_input" : return false
		if v_sig_name == "draw" and v_met_name == "ColorPicker::_sample_draw" : return false
		if v_sig_name == "id_pressed" and v_met_name == "ColorPicker::set_picker_shape" : return false
		if v_sig_name == "pressed" and v_met_name == "ColorPicker::set_color_mode" : return false
		if v_sig_name == "id_pressed" and v_met_name == "ColorPicker::_set_mode_popup_value" : return false
		if v_sig_name == "drag_started" and v_met_name == "ColorPicker::_slider_drag_started" : return false
		if v_sig_name == "value_changed" and v_met_name == "ColorPicker::_slider_value_changed" : return false
		if v_sig_name == "drag_ended" and v_met_name == "ColorPicker::_slider_drag_ended" : return false
		if v_sig_name == "draw" and v_met_name == "ColorPicker::_slider_draw" : return false
		if v_sig_name == "gui_input" and v_met_name == "ColorPicker::_line_edit_input" : return false
		if v_sig_name == "gui_input" and v_met_name == "ColorPicker::_slider_or_spin_input" : return false
		if v_sig_name == "pressed" and v_met_name == "ColorPicker::_text_type_toggled" : return false
		if v_sig_name == "text_submitted" and v_met_name == "ColorPicker::_html_submitted" : return false
		if v_sig_name == "text_changed" and v_met_name == "ColorPicker::_text_changed" : return false
		if v_sig_name == "focus_exited" and v_met_name == "ColorPicker::_html_focus_exit" : return false
		if v_sig_name == "draw" and v_met_name == "ColorPicker::_hsv_draw" : return false
		if v_sig_name == "gui_input" and v_met_name == "ColorPicker::_uv_input" : return false
		if v_sig_name == "gui_input" and v_met_name == "ColorPicker::_w_input" : return false
		if v_sig_name == "toggled" and v_met_name == "ColorPicker::_show_hide_preset" : return false
		if v_sig_name == "pressed" and v_met_name == "ColorPicker::_add_preset_pressed": return false
	if v_met_obj is CodeEdit:
		if v_sig_name == "m_lines_edited_from" and v_met_name == "CodeEdit::_m_lines_edited_from": return false
		if v_sig_name == "text_set" and v_met_name == "CodeEdit::_text_set": return false
		if v_sig_name == "text_changed" and v_met_name == "CodeEdit::_text_changed": return false
		if v_sig_name == "gutter_clicked" and v_met_name == "CodeEdit::_gutter_clicked": return false
		if v_sig_name == "gutter_added" and v_met_name == "CodeEdit::_update_gutter_indexes": return false
		if v_sig_name == "gutter_removed" and v_met_name == "CodeEdit::_update_gutter_indexes": return false
	if v_met_obj is AcceptDialog:
		if v_sig_name == "visibility_changed" and v_met_name == "AcceptDialog::_custom_button_visibility_changed" : return false
		if v_sig_name == "pressed" and v_met_name == "AcceptDialog::_cancel_pressed" : return false
		if v_sig_name == "pressed" and v_met_name == "AcceptDialog::_ok_pressed": return false
		if v_sig_name == "window_input" and v_met_name == "AcceptDialog::_input_from_window": return false
	return true
