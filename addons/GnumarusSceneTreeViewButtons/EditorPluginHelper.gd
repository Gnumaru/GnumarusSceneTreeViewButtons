#class_name GnumarusSceneTreeViewButtonsEditorPluginHelper
@tool
extends RefCounted


class TreeItemInfo:
	extends RefCounted
	var btns_ids: Dictionary  #[String, int]
	var treeitem: TreeItem
	var nodepath: NodePath
	var node: Node


const DEBUG_VERBOSE: bool = true
const IGNORE_CONNECTIONS_TO_NATIVE_METHODS: bool = false

var TreeItemHelper: GDScript

var mdescriptionbtntex: Texture2D
var mincomingconnectionsbtntex: Texture2D
var mmetasbtntex: Texture2D

var meditedscenetreetree: Tree

var maddondir: String
var mitemstobtnmap: Dictionary  #[TreeItem, TreeItemInfo]
var mlastchecktimems: int = -999999
var mlasteditedscene = null


func _init() -> void:
	_print("_init()", "\n")
	maddondir = get_script().resource_path.get_base_dir()
	TreeItemHelper = load(maddondir + "/TreeItemHelper.gd")
	mdescriptionbtntex = load(maddondir + "/EditorCommentSceneTreeViewIcon.svg")
	mincomingconnectionsbtntex = load(maddondir + "/IncomingConnectionsSceneTreeViewIcon.svg")
	mmetasbtntex = load(maddondir + "/MetasSceneTreeViewIcon.svg")
	mitemstobtnmap = {}


func _print(pafter: Variant, pbefore: Variant = "") -> void:
	print("%s- GnumarusSceneTreeViewButtonsEditorPlugin: %s" % [pbefore, pafter])


func on_scene_view_tree_rebuilt():
	_print("on_scene_view_tree_rebuilt()")
	var vlow_processor_usage_mode: bool = OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	# waiting some frames since the previous tree predelete is called BEFORE the tree is deleted
	while is_instance_valid(meditedscenetreetree):
		await Engine.get_main_loop().process_frame
	OS.low_processor_usage_mode = vlow_processor_usage_mode
	setup()


func update():
	var vnowms: int = Time.get_ticks_msec()
	var vcureditedscene = Engine.get_main_loop().edited_scene_root

	if vcureditedscene != mlasteditedscene:
		mlastchecktimems = vnowms
		setup()
	else:
		var vdiffms: int = vnowms - mlastchecktimems
		if vdiffms < 1000:
			return
		mlastchecktimems = vnowms
		setup()


func setup():
	var veditorrootwindow: Window = Engine.get_main_loop().root
	if not is_instance_valid(meditedscenetreetree):
		meditedscenetreetree = get_scene_tree_view_tree_control()
	if not is_instance_valid(meditedscenetreetree):
		print('couldnt find scene tree view')
		return
	if not meditedscenetreetree.button_clicked.is_connected(on_button_clicked):
		meditedscenetreetree.button_clicked.connect(on_button_clicked)
	var vscenetreeitem: TreeItem = meditedscenetreetree.get_root()
	if not is_instance_valid(vscenetreeitem):
		# can be invalid uppon opening the editor the fist time
		return
	var vcolumn: int = 0
	mlasteditedscene = veditorrootwindow.get_node(vscenetreeitem.get_metadata(vcolumn))
	if not is_instance_valid(vscenetreeitem) or vscenetreeitem.get_script() == TreeItemHelper:
		return
	#_print("setup()")
	clean_invalid_tree_items()
	vscenetreeitem.set_script(TreeItemHelper)
	# predelete.connect() won't work for unknow reasons, it says it cant find connect() on Signal
	vscenetreeitem.connect("predelete", on_scene_view_tree_rebuilt)

	var mnextbtnid: int = 100  # 2147483647
	var vinc: int = +1  # -1

	while is_instance_valid(vscenetreeitem):
		var vnodepath: NodePath = vscenetreeitem.get_metadata(vcolumn) as NodePath
		var vnode: Node = veditorrootwindow.get_node(vnodepath)
		var vbtncount: int = vscenetreeitem.get_button_count(vcolumn)

		var vhasdescriptiontxt:bool = vnode.editor_description.length() > 0
		var vhasincomingconnections:bool = (
			vnode.get_incoming_connections().filter(connection_filter).size() > 0
		)
		var vhasmeta:bool = vnode.get_meta_list().filter(meta_filter).size() > 0

		var vhasdescriptionbtn: bool = false
		var vhasincomingconnectionsbtn: bool = false
		var vhasmetabtn: bool = false

		for i in vscenetreeitem.get_button_count(vcolumn):
			var vbtntooltip: String = vscenetreeitem.get_button_tooltip_text(vcolumn, i)
			match vbtntooltip:
				"editor_description":
					vhasdescriptionbtn = true
				"incoming_connections":
					vhasincomingconnectionsbtn = true
				"metas":
					vhasmetabtn = true

		var vtreeinfo: TreeItemInfo = TreeItemInfo.new()
		vtreeinfo.btns_ids = {}
		vtreeinfo.treeitem = vscenetreeitem
		vtreeinfo.nodepath = vnodepath
		vtreeinfo.node = vnode

		mitemstobtnmap[vscenetreeitem] = vtreeinfo

		if vhasdescriptiontxt and not vhasdescriptionbtn:
			while vscenetreeitem.get_button_by_id(vcolumn, mnextbtnid) >= 0:
				mnextbtnid += vinc
			vtreeinfo.btns_ids.editor_description = mnextbtnid
			vscenetreeitem.add_button(
				vcolumn, mdescriptionbtntex, mnextbtnid, false, "editor_description"
			)
			mnextbtnid += vinc

		if vhasincomingconnections and not vhasincomingconnectionsbtn:
			while vscenetreeitem.get_button_by_id(vcolumn, mnextbtnid) >= 0:
				mnextbtnid += vinc
			vtreeinfo.btns_ids.incoming_connections = mnextbtnid
			vscenetreeitem.add_button(
				vcolumn, mincomingconnectionsbtntex, mnextbtnid, false, "incoming_connections"
			)
			mnextbtnid += vinc

		if vhasmeta and not vhasmetabtn:
			while vscenetreeitem.get_button_by_id(vcolumn, mnextbtnid) >= 0:
				mnextbtnid += vinc
			vtreeinfo.btns_ids.metas = mnextbtnid
			vscenetreeitem.add_button(
				vcolumn, mmetasbtntex, mnextbtnid, false, "metas"
			)
			mnextbtnid += vinc

		vscenetreeitem = vscenetreeitem.get_next_visible()


func meta_filter(pmetaname: String) -> bool:
	match pmetaname:
		"_edit_lock_":
			return false
		"_edit_group_":
			return false
		"_aseprite_wizard_interface_config_":
			# from the aseprite AsepriteWizard addon
			return false
	return true





func on_editor_description_clicked(ptreeiteminfo: TreeItemInfo):
	var vnode: Node = ptreeiteminfo.node
	var vlast: TreeItem = meditedscenetreetree.get_selected()
	var vwassame: bool = vlast == ptreeiteminfo.treeitem
	meditedscenetreetree.set_selected(ptreeiteminfo.treeitem, 0)
	if not vwassame:
		var vlow_processor_usage_mode: bool = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = false
		for i in 10:  # HACK: TODO: find proper way of telling that the editor has updated and only proceed after update
			await Engine.get_main_loop().process_frame
		OS.low_processor_usage_mode = vlow_processor_usage_mode

	var veditordescriptionbtn: Node = get_editor_description_button()
	veditordescriptionbtn.pressed.emit()


func _alert(ptext: String, ptitle: String = "Message") -> void:
	var vdiag: AcceptDialog = AcceptDialog.new()
	vdiag.dialog_text = ptext
	vdiag.title = ptitle
	vdiag.close_requested.connect(vdiag.queue_free)
	# do not block input to the main window but let the alert always on top so that the user may search the signal emitters while keeping the modal open for reading the node path
	vdiag.exclusive = false
	vdiag.always_on_top = true

	EditorInterface.get_base_control().add_child(vdiag)
	vdiag.popup_centered()


func on_metas_clicked(ptreeiteminfo: TreeItemInfo):
	var vnode = ptreeiteminfo.node
	var vsceneroot: Node = vnode.owner
	if not is_instance_valid(vsceneroot):
		vsceneroot = vnode
	var vnodepathfromsceneroot = str(vsceneroot.get_path_to(vnode))
	if vnodepathfromsceneroot == '.':
		vnodepathfromsceneroot += ' (%s)'%vnode.name

	var vdict:Dictionary = {}
	for imetaname:String in vnode.get_meta_list().filter(meta_filter):
		vdict[imetaname] = vnode.get_meta(imetaname)
	var vmsg:String = "metas for %s\n%s\n"%[vnodepathfromsceneroot, vdict]
	print(vmsg)
	_alert(vmsg, "metas for %s" % vnodepathfromsceneroot)


func on_incoming_connections_clicked(ptreeiteminfo: TreeItemInfo):
	var vnode = ptreeiteminfo.node
	var vsceneroot: Node = vnode.owner
	if not is_instance_valid(vsceneroot):
		vsceneroot = vnode
	var vnodepathfromsceneroot = vsceneroot.get_path_to(vnode)
	var vcons_info = ptreeiteminfo.node.get_incoming_connections().filter(connection_filter)

	var vmsg: String = (
		'\n%s has the following "%s" incomming node connections\n'
		% [vnodepathfromsceneroot, vcons_info.size()]
	)

	for iconinfo: Dictionary in vcons_info:
		var vsig: Signal = iconinfo.signal
		var vmet: Callable = iconinfo.callable
		var vemiter: Object = vsig.get_object()
		var vsigpath: String = "signal %s.%s" % [vsceneroot.get_path_to(vemiter), vsig.get_name()]
		var vmetpath: String = (
			"method %s.%s"
			% [vsceneroot.get_path_to(vmet.get_object()), iconinfo.callable.get_method()]
		)
		vmsg += "  %s\n  %s\n\n" % [vsigpath, vmetpath]
		#print(' %s\n %s\n'%[vsigpath, vmetpath])
		print('if vsigname == "%s" and vmetname == "%s": return false'%[vsig.get_name(), iconinfo.callable.get_method()])

	vmsg += "\n"
	print(vmsg)
	_alert(vmsg, "Incoming Connections for %s" % vnodepathfromsceneroot)


func on_button_clicked(
	pitem: TreeItem, pcolumnidx: int, pbtnid: int, pmouse_button_index: int
) -> void:
	if not pitem in mitemstobtnmap:
		# unmaped tree item
		return

	var vtreeiteminfo: TreeItemInfo = mitemstobtnmap[pitem]
	if vtreeiteminfo.treeitem != pitem:
		# this should be impossible, but let's just play safe
		return

	for ibtntooltip in vtreeiteminfo.btns_ids:
		match ibtntooltip:
			"editor_description":
				if pbtnid == vtreeiteminfo.btns_ids.editor_description:
					on_editor_description_clicked(vtreeiteminfo)
			"incoming_connections":
				if pbtnid == vtreeiteminfo.btns_ids.incoming_connections:
					on_incoming_connections_clicked(vtreeiteminfo)
			"metas":
				if pbtnid == vtreeiteminfo.btns_ids.metas:
					on_metas_clicked(vtreeiteminfo)

	clean_invalid_tree_items()


func clean_invalid_tree_items():
	for i in mitemstobtnmap:
		if not is_instance_valid(i):
			mitemstobtnmap.erase(i)


func get_scene_tree_view_tree_control() -> Tree:
	# diferent from, say, the inspector, which has a editor interface getter (EditorInterface.get_inspector()) there is no getter for the SceneTreeDock which even has a properly named node "Scene"
	return get_node_robust(
		Engine.get_main_loop().root,
		[
			#name childindex nativeclass classname forwardsearch skipcount
			["@EditorNode@17147", 0, null, "EditorNode", true, 0],
			["@Panel@13", 4, Panel, "Panel", true, 0],
			["@VBoxContainer@14", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@HSplitContainer@17", 1, HSplitContainer, "HSplitContainer", true, 0],
			["@HSplitContainer@25", 1, HSplitContainer, "HSplitContainer", true, 0],
			["@VSplitContainer@27", 0, VSplitContainer, "VSplitContainer", true, 0],
			["@TabContainer@29", 0, TabContainer, "TabContainer", true, 0],
			["Scene", 1, null, "SceneTreeDock", true, 0],
			["@SceneTreeEditor@4247", 3, null, "SceneTreeEditor", true, 0],
			["@Tree@4231", 0, Tree, "Tree", true, 0],
		]
	)


func get_editor_description_button() -> Button:
	# TODO: instead of Engine.get_main_loop().root, use EditorInterface.get_inspector() and search from there with a much shorter path
	var v = get_node_robust(
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
	if not is_instance_valid(v):
		print("trying again")
		v = get_node_robust(
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
	return v


func type_check(p: Node, pnativeclass: Variant, pclassname: String) -> Node:
	# if found by name, validate the node type
	var vfound: bool = true
	# and check
	if is_instance_valid(pnativeclass) and not is_instance_of(p, pnativeclass):
		vfound = false
	if (
		vfound
		and not pclassname.is_empty()
		and not ClassDB.is_parent_class(p.get_class(), pclassname)
	):
		vfound = false
	if vfound:
		return p
	return null


## there is absolutely no guarantee that the editor node names and child node index will keep the same while using diferent versions of godot or even while using the editor. We can never expect that a simple nodepath will continue working. so instead of using simple nodepaths I'm using a path composed of arguments for searching each children step by step using several fallbacks (name, then index, then searching the nth node whose type matches. It is still not guarateed to work, but at least it is sligtly better than a plain nodepath search
func get_node_robust(proot: Node, ppath: Array) -> Node:
	# TODO maybe implement backtracking. if the search down a path was'nt suceeded, backtrack the parent and try again
	var vcurrent: Node = proot
	var vtypecheckfunc: Callable = type_check

	for ipathstepidx in ppath.size():
		var vparams: Array = ppath[ipathstepidx]
		var vname: String = vparams[0]
		var vchildidx: int = vparams[1]
		var vnativeclass: Variant = vparams[2]
		var vclassname: String = vparams[3]
		var vforwardsearch: bool = vparams[4]
		var vskips: int = vparams[5]
		var vnext: Node

		# first, try to get the node by name
		vnext = vcurrent.get_node_or_null(vname)
		if is_instance_valid(vnext):
			vnext = vtypecheckfunc.call(vnext, vnativeclass, vclassname)
			if is_instance_valid(vnext):
				vcurrent = vnext
				if DEBUG_VERBOSE:
					print("found path step by name: %s, %s" % [ipathstepidx, vname])
				continue

		# TODO instead of using a single index, have two indexes, one from the start and one from the end
		# if couldnt find it by type, find by index
		if absi(vchildidx) < 100:
			if vchildidx < vcurrent.get_child_count() and vchildidx >= -vcurrent.get_child_count():
				vnext = vcurrent.get_child(vchildidx)
			vnext = vtypecheckfunc.call(vnext, vnativeclass, vclassname)
			if is_instance_valid(vnext):
				vcurrent = vnext
				if DEBUG_VERBOSE:
					print("found path step by index: %s, %s" % [ipathstepidx, vname])
				continue

		# if search by name didn't worked, iterate all children and search by type
		var vremskips: int = vskips
		if vforwardsearch:
			for ifwdidx in vcurrent.get_child_count():
				var vchild = vcurrent.get_child(ifwdidx)
				if is_instance_valid(vnativeclass) and not is_instance_of(vchild, vnativeclass):
					#print('wrong nativeclass. expected %s got %s'%[vclassname, vchild.get_class()])
					if ifwdidx == vcurrent.get_child_count() - 1:
						if DEBUG_VERBOSE:
							print("no more children")
					continue
				if (
					not vclassname.is_empty()
					and not ClassDB.is_parent_class(vchild.get_class(), vclassname)
				):
					if DEBUG_VERBOSE:
						print("wrong classname %s, %s" % [vclassname, vchild.get_class()])
					if ifwdidx == vcurrent.get_child_count() - 1:
						if DEBUG_VERBOSE:
							print("no more children")
					continue
				if vremskips <= 0:
					vnext = vchild
					if DEBUG_VERBOSE:
						print(
							(
								"found path step by type with forward search and %s skips: %s, expected %s, got %s"
								% [vskips, ipathstepidx, vname, vnext.name]
							)
						)
					break
				else:
					vremskips -= 1
					if ifwdidx == vcurrent.get_child_count() - 1:
						if DEBUG_VERBOSE:
							print("no more children")
		else:
			for ibackidx in range(vcurrent.get_child_count() - 1, -1, -1):
				var vchild = vcurrent.get_child(ibackidx)
				if is_instance_valid(vnativeclass) and not is_instance_of(vchild, vnativeclass):
					continue
				if (
					not vclassname.is_empty()
					and not ClassDB.is_parent_class(vchild.get_class(), vclassname)
				):
					continue
				if vremskips <= 0:
					vnext = vchild
					if DEBUG_VERBOSE:
						print(
							(
								"found path step by type with backwards search and %s skips: %s, expected %s, got %s"
								% [vskips, ipathstepidx, vname, vnext.name]
							)
						)
					break
				else:
					vremskips -= 1

		if is_instance_valid(vnext):
			vcurrent = vnext
		else:
			if DEBUG_VERBOSE:
				print('failed at step "%s" of path (%s)' % [ipathstepidx, vparams])
			return null
	return vcurrent


func connection_filter(pdictionary: Dictionary) -> bool:
	var vsig: Signal = pdictionary.signal
	var vsignaler: Object = vsig.get_object()

	if not vsignaler is Node:
		return false

	var vmet: Callable = pdictionary.callable
	var vmetname: String = vmet.get_method()

	if IGNORE_CONNECTIONS_TO_NATIVE_METHODS and "::" in vmetname:
		return false

	var vmetobj: Object = vmet.get_object()
	var vsigname: String = vsig.get_name()

	if vmetobj is CanvasItem:
		if (
			vsignaler == vmetobj.get_parent()
			and vsigname == "item_rect_changed"
			and vmetname == "Control::_size_changed"
		):
			return false
	if vmetobj is Container:
		if vsigname == "size_flags_changed" and vmetname == "Container::queue_sort": return false
		if vsigname == "minimum_size_changed" and vmetname == "Container::_child_minsize_changed": return false
		if vsigname == "visibility_changed" and vmetname == "Container::_child_minsize_changed": return false
	if vmetobj is Camera3D:
		if vsigname == "size_changed" and vmetname == "Camera3D::update_gizmos": return false
	if vmetobj is Tree:
		if vsigname == "timeout" and vmetname == "Tree::_range_click_timeout": return false
		if vsigname == "value_changed" and vmetname == "Tree::_scroll_moved": return false
		if vsigname == "text_submitted" and vmetname == "Tree::_line_editor_submit": return false
		if vsigname == "gui_input" and vmetname == "Tree::_text_editor_gui_input": return false
		if vsigname == "popup_hide" and vmetname == "Tree::_text_editor_popup_modal_close": return false
		if vsigname == "id_pressed" and vmetname == "Tree::popup_select": return false
		if vsigname == "value_changed" and vmetname == "Tree::value_editor_changed": return false
	if vmetobj is TextEdit:
		if vsigname == "value_changed" and vmetname == "TextEdit::_scroll_moved": return false
		if vsigname == "scrolling" and vmetname == "TextEdit::_v_scroll_input": return false
		if vsigname == "timeout" and vmetname == "TextEdit::_toggle_draw_caret": return false
		if vsigname == "timeout" and vmetname == "TextEdit::_click_selection_held": return false
		if vsigname == "timeout" and vmetname == "TextEdit::_push_current_op": return false
	if vmetobj is TabContainer:
		if vsigname == "tab_changed" and vmetname == "TabContainer::_on_tab_changed": return false
		if vsigname == "tab_clicked" and vmetname == "TabContainer::_on_tab_clicked": return false
		if vsigname == "tab_hovered" and vmetname == "TabContainer::_on_tab_hovered": return false
		if vsigname == "tab_selected" and vmetname == "TabContainer::_on_tab_selected": return false
		if vsigname == "tab_button_pressed" and vmetname == "TabContainer::_on_tab_button_pressed": return false
		if vsigname == "active_tab_rearranged" and vmetname == "TabContainer::_on_active_tab_rearranged": return false
		if vsigname == "mouse_exited" and vmetname == "TabContainer::_on_mouse_exited": return false
	if vmetobj is TabBar:
		if vsigname == "mouse_exited" and vmetname == "TabBar::_on_mouse_exited": return false
	if vmetobj is SpinBox:
		if vsigname == "text_submitted" and vmetname == "SpinBox::_text_submitted": return false
		if vsigname == "focus_entered" and vmetname == "SpinBox::_line_edit_focus_enter": return false
		if vsigname == "focus_exited" and vmetname == "SpinBox::_line_edit_focus_exit": return false
		if vsigname == "gui_input" and vmetname == "SpinBox::_line_edit_input": return false
		if vsigname == "timeout" and vmetname == "SpinBox::_range_click_timeout": return false
	if vmetobj is ScrollContainer:
		if vsigname == "value_changed" and vmetname == "ScrollContainer::_scroll_moved": return false
		if vsigname == "gui_focus_changed" and vmetname == "ScrollContainer::_gui_focus_changed": return false
	if vmetobj is RichTextLabel:
		if vsigname == "value_changed" and vmetname == "RichTextLabel::_scroll_changed": return false
	if vmetobj is Viewport:
		if vsigname == "child_order_changed" and vmetname == "Viewport::gui_set_root_order_dirty": return false
		if vsigname == "child_order_changed" and vmetname == "Viewport::canvas_parent_mark_dirty": return false
	if vmetobj is PopupMenu:
		if vsigname == "draw" and vmetname == "PopupMenu::_draw_background": return false
		if vsigname == "draw" and vmetname == "PopupMenu::_draw_items": return false
		if vsigname == "window_input" and vmetname == "PopupMenu::gui_input": return false
		if vsigname == "timeout" and vmetname == "PopupMenu::_submenu_timeout": return false
		if vsigname == "timeout" and vmetname == "PopupMenu::_minimum_lifetime_timeout": return false
	if vmetobj is Popup:
		if vsigname == "window_input" and vmetname == "Popup::_input_from_window": return false
	if vmetobj is PathFollow2D:
		if vsigname == "timeout" and vmetname == "PathFollow2D::_update_transform": return false
	if vmetobj is BaseButton:
		if vsigname == "popup_hide" and vmetname == "BaseButton::set_pressed": return false
	if vmetobj is OptionButton:
		if vsigname == "index_pressed" and vmetname == "OptionButton::_selected": return false
		if vsigname == "id_focused" and vmetname == "OptionButton::_focused": return false
	if vmetobj is MenuButton:
		if vsigname == "about_to_popup" and vmetname == "MenuButton::_popup_visibility_changed": return false
		if vsigname == "popup_hide" and vmetname == "MenuButton::_popup_visibility_changed": return false
	if vmetobj is Label3D:
		if vsigname == "size_changed" and vmetname == "Label3D::_font_changed": return false
	if vmetobj is ItemList:
		if vsigname == "value_changed" and vmetname == "ItemList::_scroll_changed": return false
		if vsigname == "mouse_exited" and vmetname == "ItemList::_mouse_exited": return false
	if vmetobj is HTTPRequest:
		if vsigname == "timeout" and vmetname == "HTTPRequest::_timeout": return false
	if vmetobj is GraphEdit:
		if vsigname == "draw" and vmetname == "GraphEdit::_top_layer_draw": return false
		if vsigname == "gui_input" and vmetname == "GraphEdit::_top_layer_input": return false
		if vsigname == "draw" and vmetname == "GraphEdit::_connections_layer_draw": return false
		if vsigname == "value_changed" and vmetname == "GraphEdit::_scroll_moved": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::_zoom_minus": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::_zoom_reset": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::_zoom_plus": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::_show_grid_toggled": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::_snapping_toggled": return false
		if vsigname == "value_changed" and vmetname == "GraphEdit::_snapping_distance_changed": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::_minimap_toggled": return false
		if vsigname == "pressed" and vmetname == "GraphEdit::arrange_nodes": return false
		if vsigname == "draw" and vmetname == "GraphEdit::_minimap_draw": return false
	if vmetobj is FileDialog:
		if vsigname == "pressed" and vmetname == "FileDialog::_go_back": return false
		if vsigname == "pressed" and vmetname == "FileDialog::_go_forward": return false
		if vsigname == "pressed" and vmetname == "FileDialog::_go_up": return false
		if vsigname == "item_selected" and vmetname == "FileDialog::_select_drive": return false
		if vsigname == "pressed" and vmetname == "FileDialog::update_file_list": return false
		if vsigname == "toggled" and vmetname == "FileDialog::set_show_hidden_files": return false
		if vsigname == "pressed" and vmetname == "FileDialog::_make_dir": return false
		if vsigname == "confirmed" and vmetname == "FileDialog::_action_pressed": return false
		if vsigname == "multi_selected" and vmetname == "FileDialog::_tree_multi_selected": return false
		if vsigname == "cell_selected" and vmetname == "FileDialog::_tree_selected": return false
		if vsigname == "item_activated" and vmetname == "FileDialog::_tree_item_activated": return false
		if vsigname == "nothing_selected" and vmetname == "FileDialog::deselect_all": return false
		if vsigname == "text_submitted" and vmetname == "FileDialog::_dir_submitted": return false
		if vsigname == "text_submitted" and vmetname == "FileDialog::_file_submitted": return false
		if vsigname == "item_selected" and vmetname == "FileDialog::_filter_selected": return false
		if vsigname == "confirmed" and vmetname == "FileDialog::_save_confirm_pressed": return false
		if vsigname == "confirmed" and vmetname == "FileDialog::_make_dir_confirm": return false
	if vmetobj is ColorPicker:
		if vsigname == "draw"and vmetname == "ColorPicker::_hsv_draw": return false
		if vsigname == "pressed" and vmetname == "ColorPicker::_pick_button_pressed" : return false
		if vsigname == "gui_input" and vmetname == "ColorPicker::_sample_input" : return false
		if vsigname == "draw" and vmetname == "ColorPicker::_sample_draw" : return false
		if vsigname == "id_pressed" and vmetname == "ColorPicker::set_picker_shape" : return false
		if vsigname == "pressed" and vmetname == "ColorPicker::set_color_mode" : return false
		if vsigname == "id_pressed" and vmetname == "ColorPicker::_set_mode_popup_value" : return false
		if vsigname == "drag_started" and vmetname == "ColorPicker::_slider_drag_started" : return false
		if vsigname == "value_changed" and vmetname == "ColorPicker::_slider_value_changed" : return false
		if vsigname == "drag_ended" and vmetname == "ColorPicker::_slider_drag_ended" : return false
		if vsigname == "draw" and vmetname == "ColorPicker::_slider_draw" : return false
		if vsigname == "gui_input" and vmetname == "ColorPicker::_line_edit_input" : return false
		if vsigname == "gui_input" and vmetname == "ColorPicker::_slider_or_spin_input" : return false
		if vsigname == "pressed" and vmetname == "ColorPicker::_text_type_toggled" : return false
		if vsigname == "text_submitted" and vmetname == "ColorPicker::_html_submitted" : return false
		if vsigname == "text_changed" and vmetname == "ColorPicker::_text_changed" : return false
		if vsigname == "focus_exited" and vmetname == "ColorPicker::_html_focus_exit" : return false
		if vsigname == "draw" and vmetname == "ColorPicker::_hsv_draw" : return false
		if vsigname == "gui_input" and vmetname == "ColorPicker::_uv_input" : return false
		if vsigname == "gui_input" and vmetname == "ColorPicker::_w_input" : return false
		if vsigname == "toggled" and vmetname == "ColorPicker::_show_hide_preset" : return false
		if vsigname == "pressed" and vmetname == "ColorPicker::_add_preset_pressed": return false
	if vmetobj is CodeEdit:
		if vsigname == "lines_edited_from" and vmetname == "CodeEdit::_lines_edited_from": return false
		if vsigname == "text_set" and vmetname == "CodeEdit::_text_set": return false
		if vsigname == "text_changed" and vmetname == "CodeEdit::_text_changed": return false
		if vsigname == "gutter_clicked" and vmetname == "CodeEdit::_gutter_clicked": return false
		if vsigname == "gutter_added" and vmetname == "CodeEdit::_update_gutter_indexes": return false
		if vsigname == "gutter_removed" and vmetname == "CodeEdit::_update_gutter_indexes": return false
	if vmetobj is AcceptDialog:
		if vsigname == "visibility_changed" and vmetname == "AcceptDialog::_custom_button_visibility_changed" : return false
		if vsigname == "pressed" and vmetname == "AcceptDialog::_cancel_pressed" : return false
		if vsigname == "pressed" and vmetname == "AcceptDialog::_ok_pressed": return false
		if vsigname == "window_input" and vmetname == "AcceptDialog::_input_from_window": return false
	return true
