#class_name GnumarusSceneTreeViewButtonsEditorPluginHelper
@tool
extends RefCounted


class TreeItemInfo:
	extends RefCounted
	var btns_ids: Dictionary  #[String, int]
	var treeitem: TreeItem
	var nodepath: NodePath
	var node: Node


const DEBUG_VERBOSE: bool = false
const IGNORE_CONNECTIONS_TO_NATIVE_METHODS: bool = false

var TreeItemHelper: GDScript

var mdescriptionbtntex: Texture2D
var mincomingconnectionsbtntex: Texture2D

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
	mitemstobtnmap = {}


func _print(pafter: Variant, pbefore: Variant = "") -> void:
	print("%s- GnumarusSceneTreeViewButtonsEditorPlugin: %s" % [pbefore, pafter])


func on_scene_view_tree_rebuilt():
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
	meditedscenetreetree = get_scene_tree_view_tree_control()
	if not meditedscenetreetree.button_clicked.is_connected(on_button_clicked):
		meditedscenetreetree.button_clicked.connect(on_button_clicked)
	var vscenetreeitem: TreeItem = meditedscenetreetree.get_root()
	if not is_instance_valid(vscenetreeitem) or vscenetreeitem.get_script() == TreeItemHelper:
		return
	_print("setup()")
	clean_invalid_tree_items()
	vscenetreeitem.set_script(TreeItemHelper)
	# predelete.connect() won't work for unknow reasons, it says it cant find connect() on Signal
	vscenetreeitem.connect("predelete", on_scene_view_tree_rebuilt)

	var mnextbtnid: int = 100  # 2147483647
	var vinc: int = +1  # -1
	var vcolumn: int = 0

	while is_instance_valid(vscenetreeitem):
		var vnodepath: NodePath = vscenetreeitem.get_metadata(vcolumn) as NodePath
		var vnode: Node = veditorrootwindow.get_node(vnodepath)
		var vbtncount: int = vscenetreeitem.get_button_count(vcolumn)

		var vhasdescriptiontxt = vnode.editor_description.length() > 0
		var vhasincomingconnections = (
			vnode.get_incoming_connections().filter(connection_filter).size() > 0
		)

		var vhasdescriptionbtn: bool = false
		var vhasincomingconnectionsbtn: bool = false

		for i in vscenetreeitem.get_button_count(vcolumn):
			var vbtntooltip: String = vscenetreeitem.get_button_tooltip_text(vcolumn, i)
			match vbtntooltip:
				"editor_description":
					vhasdescriptionbtn = true
				"incoming_connections":
					vhasincomingconnectionsbtn = true

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

		vscenetreeitem = vscenetreeitem.get_next_visible()


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

	# canvasitem
	if (
		vsignaler == vmetobj.get_parent()
		and vsigname == "item_rect_changed"
		and vmetname == "Control::_size_changed"
	):
		return false

	# xrcamera3d
	if vsigname == "size_changed" and vmetname == "Camera3D::update_gizmos":  # TODO check signaler
		return false

	# vsplitcontainer
	if vsigname == "size_flags_changed" and vmetname == "Container::queue_sort":  # TODO check signaler
		return false
	if vsigname == "minimum_size_changed" and vmetname == "Container::_child_minsize_changed":  # TODO check signaler
		return false
	if vsigname == "visibility_changed" and vmetname == "Container::_child_minsize_changed":  # TODO check signaler
		return false

	# tree
	if vsigname == "timeout" and vmetname == "Tree::_range_click_timeout":  # TODO check signaler
		return false
	if vsigname == "value_changed" and vmetname == "Tree::_scroll_moved":  # TODO check signaler
		return false
	if vsigname == "value_changed" and vmetname == "Tree::value_editor_changed":  # TODO check signaler
		return false
	if vsigname == "text_submitted" and vmetname == "Tree::_line_editor_submit":  # TODO check signaler
		return false
	if vsigname == "gui_input" and vmetname == "Tree::_text_editor_gui_input":  # TODO check signaler
		return false
	if vsigname == "popup_hide" and vmetname == "Tree::_text_editor_popup_modal_close":  # TODO check signaler
		return false
	if vsigname == "id_pressed" and vmetname == "Tree::popup_select":  # TODO check signaler
		return false

	# TODO setup all the exclusions bellow =O =(
	# textedit
	# tabcontainer
	# tabbar
	# spinbox
	# scrollcontainer
	# richtextlabel
	# popuppanel
	# popupmenu
	# popup
	# pathfollow2d
	# optionbutton
	# menubutton
	# label3d
	# itemlist
	# httprequest
	# graphedit
	# filedialog
	# confirmationdialog
	# colorpicker
	# codeedit
	# acceptdialog
	if vsigname == "pressed" and vmetname == "AcceptDialog::_ok_pressed":  # TODO check signaler
		return false
	if vsigname == "window_input" and vmetname == "AcceptDialog::_input_from_window":  # TODO check signaler
		return false
	if vsigname == "child_order_changed" and vmetname == "Viewport::gui_set_root_order_dirty":  # TODO check signaler
		return false
	if vsigname == "child_order_changed" and vmetname == "Viewport::canvas_parent_mark_dirty":  # TODO check signaler
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


func on_incoming_connections_clicked(ptreeiteminfo: TreeItemInfo):
	var vnode = ptreeiteminfo.node
	var vsceneroot: Node = vnode.owner
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

	clean_invalid_tree_items()


func clean_invalid_tree_items():
	for i in mitemstobtnmap:
		if not is_instance_valid(i):
			mitemstobtnmap.erase(i)


func get_scene_tree_view_tree_control() -> Tree:
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
	return get_node_robust(
		Engine.get_main_loop().root,
		[
			#name childindex nativeclass classname forwardsearch skipcount
			["@EditorNode@17147", 0, null, "EditorNode", true, 0],
			["@Panel@13", 4, Panel, "Panel", true, 0],
			["@VBoxContainer@14", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@HSplitContainer@17", 1, HSplitContainer, "HSplitContainer", true, 0],
			["@HSplitContainer@25", 1, HSplitContainer, "HSplitContainer", true, 0],
			["@HSplitContainer@33", 1, HSplitContainer, "HSplitContainer", true, 0],
			["@HSplitContainer@38", 1, HSplitContainer, "HSplitContainer", true, 0],
			["@VSplitContainer@40", 0, VSplitContainer, "VSplitContainer", true, 0],
			["@TabContainer@42", 0, TabContainer, "TabContainer", true, 0],
			["Inspector", 1, null, "InspectorDock", true, 0],
			["@EditorInspector@5441", -1, EditorInspector, "EditorInspector", false, 0],
			["@VBoxContainer@5440", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@EditorInspectorSection@22022", -4, null, "EditorInspectorSection", false, 0],
			["@VBoxContainer@22023", 0, VBoxContainer, "VBoxContainer", true, 0],
			["@EditorPropertyMultilineText@22032", 0, null, "EditorPropertyMultilineText", true, 0],
			["@HBoxContainer@22024", 0, HBoxContainer, "HBoxContainer", true, 0],
			["@Button@22031", -1, Button, "Button", false, 0]
		]
	)


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
							print("no more childrent")
					continue
				if (
					not vclassname.is_empty()
					and not ClassDB.is_parent_class(vchild.get_class(), vclassname)
				):
					if DEBUG_VERBOSE:
						print("wrong classname %s, %s" % [vclassname, vchild.get_class()])
					if ifwdidx == vcurrent.get_child_count() - 1:
						if DEBUG_VERBOSE:
							print("no more childrent")
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
							print("no more childrent")
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
